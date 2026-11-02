"""Overlay patch: admit linear acquired values in native resource scopes.

Applied by `experiments/overlay.py --patch experiments/linear-resources/patch_resources.py`
to a copy of `src/fp`; `src/` is never changed. Every lease stores its value in `_Held`, which is Deinitable whatever
the value is. `_Held` destroys a Deinitable value normally and aborts only if a
linear value is still inside when the lease is destroyed, which the scope never
allows. A `comptime if` in its destructor chooses the behavior. The probe's first
versions used a conditional type alias, then Optional storage; both made
composed (`map`) scopes take minutes to compile.

The linear entry point is `linear_resource`. Sharing the name `resource` crashes
Mojo 1.2.0 overload resolution (see native/overload_crash.mojo).
"""


def sub(text, old, new, count=1):
    found = text.count(old)
    if found != count:
        raise SystemExit(f'patch_resources: expected {count} occurrence(s), found {found}:\n{old}')
    return text.replace(old, new)


PARTS = ('widen', 'held', 'linear')


def patch(folder, parts=None):
    """Apply the named parts: `widen` (releasers may hold linear values), `held`
    (leases store values in _Held), `linear` (the linear entry point; needs both)."""
    parts = parts or PARTS
    path = folder / 'fp' / 'effects' / 'resources.mojo'
    s = path.read_text()
    if 'linear' in parts and not {'widen', 'held'} <= set(parts):
        raise SystemExit('patch_resources: linear needs widen and held')

    s = sub(s, 'from std.memory import MaybeUninit\n', 'from std.memory import MaybeUninit\nfrom std.os import abort\n')
    s = sub(s, 'from fp.callables.protocols import ThunkContract, UnaryContract, Unary, BorrowCallContract, BorrowOnceCallable\n',
            'from fp.callables.protocols import ThunkContract, UnaryContract, Unary, BorrowCallContract, BorrowOnceCallable, OnceThunk\n')

    # Releasers may release a linear value.
    if 'widen' in parts:
        s = sub(s, 'trait _Releaser(Movable, Deinitable):\n    comptime Value: Movable & Deinitable',
            'trait _Releaser(Movable, Deinitable):\n    comptime Value: Movable')
    if 'held' in parts:
        s = _held(s)
    if 'linear' in parts:
        s = _linear(s)
    path.write_text(s)
    if 'held' in parts:
        effectful = folder / 'fp' / 'effects' / 'effectful_resources.mojo'
        text = effectful.read_text()
        text = sub(text, '_Lease[_DropResource[Self.F.Value, Self.E]](result^._take_ok(), _DropResource[Self.F.Value, Self.E]())',
                   '_Lease[_DropResource[Self.F.Value, Self.E]](_Held(result^._take_ok()), _DropResource[Self.F.Value, Self.E]())')
        text = sub(text, 'rebind[Self.F.Input](lease.value)', 'rebind[Self.F.Input](lease.value[])')
        text = sub(text, 'rebind[Self.F.Input](left.value)', 'rebind[Self.F.Input](left.value[])')
        text = sub(text, 'from .resources import Resource, _ResourceType, _OpenScope, _Releaser, _Lease,',
                   'from .resources import Resource, _ResourceType, _OpenScope, _Releaser, _Lease, _Held,')
        effectful.write_text(text)
    if 'linear' in parts:
        init = folder / 'fp' / 'effects' / '__init__.mojo'
        text = init.read_text()
        text = sub(text, 'from .resources import Resource, ResourceContract, resource, pure_resource\n',
                   'from .resources import Resource, ResourceContract, resource, pure_resource, linear_resource\n')
        init.write_text(text)


def _held(s):
    # Leases hold their value in _Held.
    s = sub(s, '''@fieldwise_init
struct _Lease[R: _Releaser](Movable):
    var value: Self.R.Value
    var releaser: Self.R
''', '''struct _Held[T: Movable](Movable):
    """A lease's acquired value. Deinitable whatever T is.

    A Deinitable value is destroyed normally. A linear value is always taken
    out by the scope before the lease is destroyed; finding one still inside
    is a library defect, so it aborts instead of leaking it. A plain field, not
    Optional storage: Optional made composed scopes take minutes to compile."""
    var _value: Self.T

    def __init__(out self, var value: Self.T):
        self._value = value^

    def __getitem__(ref self) -> ref[self._value] Self.T:
        return self._value

    def take(deinit self) -> Self.T:
        return self._value^

    def __deinit__(deinit self):
        comptime if conforms_to(Self.T, Deinitable):
            _ = rebind_var[downcast[Self.T, Movable & Deinitable]](self._value^)
        else:
            abort("fp: an acquired linear value was abandoned inside a resource scope")


@fieldwise_init
struct _Lease[R: _Releaser](Movable):
    # Call sites wrap the acquired value in _Held explicitly.
    var value: _Held[Self.R.Value]
    var releaser: Self.R

    def payload(ref self) -> Pointer[Self.R.Value, origin_of(self.value)]:
        """The acquired value, borrowed in place."""
        return Pointer(to=self.value[]).unsafe_origin_cast[origin_of(self.value)]()
''')
    s = sub(s, '''        return rebind_var[Outcome[T, E]](self.releaser^.release(self.value^, rebind_var[Outcome[T, Self.R.Error]](body^), context))
    def into_parts(deinit self) -> Tuple[Self.R.Value, Self.R]:
        return (self.value^, self.releaser^)''', '''        return rebind_var[Outcome[T, E]](self.releaser^.release(self.value^.take(), rebind_var[Outcome[T, Self.R.Error]](body^), context))
    def into_held_parts(deinit self) -> Tuple[_Held[Self.R.Value], Self.R]:
        return (self.value^, self.releaser^)''')

    # Borrow sites use the in-place payload.
    s = sub(s, 'Pointer(to=rebind[Self.F.Payload](left.value))',
            'rebind[Pointer[Self.F.Payload, origin_of(left.value)]](left.payload())')
    s = sub(s, 'Pointer(to=rebind[F.Payload](lease.value))',
            'rebind[Pointer[F.Payload, origin_of(lease.value)]](lease.payload())')

    # Pair composition moves held parts; a product of linear values is rejected.
    s = sub(s, '''        var left_slot = MaybeUninit[Self.L.Value]()
        var right_slot = MaybeUninit[Self.R.Value]()
        _take_pair(value^, left_slot, right_slot)
        var left = _Lease(left_slot^.unsafe_assume_init(), self.left^)
        var right = _Lease(right_slot^.unsafe_assume_init(), self.right^)''', '''        comptime assert conforms_to(Self.L.Value, Deinitable) and conforms_to(Self.R.Value, Deinitable), "fp: a product of linear resources is not supported"
        comptime LV = downcast[Self.L.Value, Movable & Deinitable]
        comptime RV = downcast[Self.R.Value, Movable & Deinitable]
        var left_slot = MaybeUninit[LV]()
        var right_slot = MaybeUninit[RV]()
        _take_pair(rebind_var[Tuple[LV, RV]](value^), left_slot, right_slot)
        var left = _Lease[Self.L](_Held(rebind_var[Self.L.Value](left_slot^.unsafe_assume_init())), self.left^)
        var right = _Lease[Self.R](_Held(rebind_var[Self.R.Value](right_slot^.unsafe_assume_init())), self.right^)''')
    s = sub(s, '''    var left_value = MaybeUninit[L.Value]()
    var left_release = MaybeUninit[L]()
    var right_value = MaybeUninit[R.Value]()
    var right_release = MaybeUninit[R]()
    _take_pair(left^.into_parts(), left_value, left_release)
    _take_pair(right^.into_parts(), right_value, right_release)
    return _Lease[_PairRelease[L, R]]((left_value^.unsafe_assume_init(), right_value^.unsafe_assume_init()), _PairRelease(left_release^.unsafe_assume_init(), right_release^.unsafe_assume_init()))''',
              '''    comptime assert conforms_to(L.Value, Deinitable) and conforms_to(R.Value, Deinitable), "fp: a product of linear resources is not supported"
    var left_value = MaybeUninit[_Held[L.Value]]()
    var left_release = MaybeUninit[L]()
    var right_value = MaybeUninit[_Held[R.Value]]()
    var right_release = MaybeUninit[R]()
    _take_pair(left^.into_held_parts(), left_value, left_release)
    _take_pair(right^.into_held_parts(), right_value, right_release)
    var pair = rebind_var[_PairRelease[L, R].Value]((left_value^.unsafe_assume_init().take(), right_value^.unsafe_assume_init().take()))
    return _Lease[_PairRelease[L, R]](_Held(pair^), _PairRelease(left_release^.unsafe_assume_init(), right_release^.unsafe_assume_init()))''')
    s = sub(s, '''    var value = MaybeUninit[R.Value]()
    var release = MaybeUninit[R]()
    _take_pair(right^.into_parts(), value, release)
    return _Lease[_HoldRelease[L, R]](value^.unsafe_assume_init(), _HoldRelease(left^, release^.unsafe_assume_init()))''',
              '''    var value = MaybeUninit[_Held[R.Value]]()
    var release = MaybeUninit[R]()
    _take_pair(right^.into_held_parts(), value, release)
    return _Lease[_HoldRelease[L, R]](rebind_var[_Held[_HoldRelease[L, R].Value]](value^.unsafe_assume_init()), _HoldRelease(left^, release^.unsafe_assume_init()))''')

    # Remaining construction sites wrap the value explicitly.
    s = sub(s, 'Ok(_Lease[Self.Release](self.value^, Self.Release()))', 'Ok(_Lease[Self.Release](_Held(self.value^), Self.Release()))')
    s = sub(s, '_close_two(self.left^, _Lease(value^, self.right^), body^, context)', '_close_two(self.left^, _Lease[Self.R](_Held(value^), self.right^), body^, context)')
    s = sub(s, 'Ok(_Lease(rebind_var[R.Value](result^._take_ok()), release^))', 'Ok(_Lease[R](_Held(rebind_var[R.Value](result^._take_ok())), release^))')

    # use_void ignores the value through a Deinitable-only adapter.
    s = sub(s, '''        var nothing: NoneType = None
        return self^.use(_IgnoreInput[Self.Value, _ValueThunk[NoneType]](_ValueThunk(nothing)))''',
            '''        comptime assert conforms_to(Self.Value, Deinitable), "fp: use_void is not available for a linear value"
        var nothing: NoneType = None
        return self^.use(rebind_var[_IgnoreInput[Self.Value, _ValueThunk[NoneType]]](_IgnoreInput[downcast[Self.Value, Movable & Deinitable], _ValueThunk[NoneType]](_ValueThunk(nothing))))''')

    return s


def _linear(s):
    # Linear acquisition and release: native callbacks, invoked through their function types.
    s = sub(s, 'def _close_two[', '''struct _HeldThunk[T: Movable, X: Movable & Deinitable, A: Movable & Deinitable](OnceThunk):
    var function: Self.A
    comptime Out = _Held[Self.T]
    comptime Error = Self.X
    def __init__(out self, var function: Self.A):
        self.function = function^
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return _Held(rebind[downcast[Self.A, def() raises Self.X -> Self.T]](self.function)())


struct _HeldRelease[T: Movable, Y: Movable & Deinitable, R: Movable & Deinitable](OnceThunk):
    var function: Self.R
    var value: _Held[Self.T]
    comptime Out = NoneType
    comptime Error = Self.Y
    def __init__(out self, var function: Self.R, var value: _Held[Self.T]):
        self.function = function^
        self.value = value^
    def call_once(deinit self) raises Self.Error -> Self.Out:
        rebind[downcast[Self.R, def(var Self.T) raises Self.Y]](self.function)(self.value^.take())
        return None


struct _LinearRelease[T: Movable, E: Movable & Deinitable, Y: Movable & Deinitable, R: Movable & Deinitable](_Releaser):
    var function: Self.R
    comptime Value = Self.T
    comptime Error = Self.E
    def __init__(out self, var function: Self.R):
        self.function = function^
    def release[U: Movable & Deinitable, C: AnyType](deinit self, var value: Self.Value, var body: Outcome[U, Self.Error], ref context: C) -> Outcome[U, Self.Error]:
        comptime assert _ErrorCompatible[Self.E, Self.Y]
        comptime assert C == NoneType, "fp: linear resources are native scopes in this probe"
        var call = _HeldRelease[Self.T, Self.Y, Self.R](self.function^, _Held(value^))
        return _finish(body^, Optional(_capture[Self.E](call^)))


struct _LinearAcquire[T: Movable, E: Movable & Deinitable, X: Movable & Deinitable, Y: Movable & Deinitable,
                      A: Movable & Deinitable, R: Movable & Deinitable](_OpenScope):
    var acquire: Self.A
    var release: Self.R
    comptime Release = _LinearRelease[Self.T, Self.E, Self.Y, Self.R]
    def __init__(out self, var acquire: Self.A, var release: Self.R):
        self.acquire = acquire^
        self.release = release^
    def open[C: AnyType](deinit self, ref context: C) -> Outcome[_Lease[Self.Release], Self.E]:
        comptime assert _ErrorCompatible[Self.E, Self.X]
        if _scope_canceled[C, Self.E](context):
            return None
        var acquired = _capture[Self.E](_HeldThunk[Self.T, Self.X, Self.A](self.acquire^))
        if acquired.is_err():
            return Optional(Result[_Lease[Self.Release], EffectFailure[Self.E]](Err(acquired^._take_err())))
        var lease = _Lease[Self.Release](acquired^._take_ok(), Self.Release(self.release^))
        return Optional(Result[_Lease[Self.Release], EffectFailure[Self.E]](Ok(lease^)))


def _close_two[''')

    s = sub(s, 'struct ResourceContract[', '''def linear_resource[T: Movable, X: Movable & Deinitable, Y: Movable & Deinitable, //, E: Movable & Deinitable,
                    A: def() raises X -> T, R: def(var T) raises Y](var acquire: A, var release: R
) -> Resource[_LinearAcquire[T, E, X, Y, A, R]] where not conforms_to(T, Deinitable) and _ErrorCompatible[E, X] and _ErrorCompatible[E, Y]:
    """Describe a native resource whose acquired value must be explicitly destroyed.

    The value is borrowed by `use` and `map`; `release` is its only consumer and
    runs exactly once after a successful acquisition, on every exit.
    """
    return Resource(_LinearAcquire[T, E, X, Y, A, R](acquire^, release^))


struct ResourceContract[''')
    return s
