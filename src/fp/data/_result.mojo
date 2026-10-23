"""Typed result values stored in place: a native Variant of `Ok` and `Err`."""
from fp.callables._conditional import _guard_owned
from fp.callables._views import _UnaryViewable
from fp.callables._retention import _Retain
from fp.callables._transforms import _Retained, _ObserveOnce
from fp.callables.protocols import Binary
from fp.functions.composition import Identity
from fp.callables.protocols import Unary, OnceUnary, OnceThunk, UnaryContract, BorrowCallable, BorrowOnceCallable
from fp.callables.invoke import call_once, invoke_borrowed, invoke_borrowed_once
from fp.adt.data import Cases, Data, Value, _ChoiceType
from std.builtin.rebind import rebind_var, downcast
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from fp.callables.protocols import BorrowCallContract, ThunkContract
from fp.callables.native import (_Unary, _RaisingUnary, _Borrowing, _RaisingBorrowing,
                                 _NativeBorrowRef, _Thunk, _RaisingThunk)
from fp.callables._receiver import _borrow_once_as, _thunk_once_as, _unary_once_as
from fp.callables._transforms import _IgnoreInput, _BorrowedUnary


trait _ResultType:
    comptime Value: Movable & Deinitable
    comptime Error: Movable & Deinitable


# A fold whose callbacks both raise requires one error type, or one of them to
# raise `Never`. This chooses that native error type; it never erases two.
comptime _ResultFailure[X: Movable & Deinitable, Y: Movable & Deinitable] = (
    _CommonError[X,Y]
)

@fieldwise_init
struct Ok[T: Movable & Deinitable](Movable, Copyable where conforms_to(T, Copyable)):
    """A successful `Result`: the value.

    It stays distinct from `Err[T]` even when the two payload types are equal.

    Parameters:
        T: The value's type.
    """
    var value: Self.T
    """The value."""

    def into_payload(deinit self) -> Self.T:
        """Consume the constructor and return its value.

        Returns:
            The value, moved out.
        """
        return self.value^


@fieldwise_init
struct Err[E: Movable & Deinitable](Movable, Copyable where conforms_to(E, Copyable)):
    """A failed `Result`: the error, stored as data rather than raised.

    Parameters:
        E: The error's type.
    """
    var value: Self.E
    """The error."""

    def into_payload(deinit self) -> Self.E:
        """Consume the constructor and return its error.

        Returns:
            The error, moved out.
        """
        return self.value^


struct _ResultCases[T: Movable & Deinitable, E: Movable & Deinitable](Data):
    """Result's data type: its two constructors, neither recursive."""
    comptime Layer[R: Value] = Cases[Ok[Self.T], Err[Self.E]]


struct Result[T: Movable & Deinitable, E: Movable & Deinitable](
    _ResultType, _ChoiceType, Movable, Copyable where conforms_to(T, Copyable) and conforms_to(E, Copyable)
):
    """A success value `Ok[T]` or a stored failure `Err[E]`, held in place in a native `Variant`.

    `Ok` and `Err` convert to a `Result` wherever its type is known, as in
    `return Ok(value)`; a payload must already have the exact type. `fp.match`
    matches a `Result` with clauses for `Ok[T]` and `Err[E]`, which borrow the
    stored constructor. It is `Copyable` only when both payloads are, and adds
    constant tag work and no heap storage.

    The transformations (`map`, `flat_map`, `map_err`, `or_else`) consume the
    Result, so they chain: `parse(text).map(twice).flat_map(check)`. A callback
    never runs on the inactive case, which passes through unchanged. A native
    error a callback raises stays a native error: it never becomes the stored
    `Err`, even when the types coincide. Callbacks are plain functions,
    closures, or library values (`Unary` for the transformations and
    `fold_owned`, `BorrowCallable` for `fold`, and the consuming forms of
    `fold_once` and `fold_owned_once`). A generic wrapper names a raising
    callback's error with `X=`, as in `value^.map[X=X](callback)`.

    `flat_tap` and `flat_pair_with` borrow the success payload for a Result
    projection, then move the original into the successful output. `followed_by`
    and `before` take zero-argument Result factories, skipped on Err. `ensure`
    borrows an Ok payload for a predicate and, only on rejection, an error
    factory. `recover` consumes an error to produce an Ok of the same success
    type, retaining the declared error type. `tap_err` borrows an Err payload
    for inspection. These operations require no payload copies and run eagerly.
    Library callbacks are consumed, including skipped callback owners; native
    callbacks are borrowed in place.

    Parameters:
        T: The success value's type.
        E: The stored error's type.
    """
    comptime Value = Self.T
    comptime Error = Self.E
    comptime Of: Data = _ResultCases[Self.T, Self.E]
    var _value: Cases[Ok[Self.T], Err[Self.E]].Subject

    @always_inline
    @implicit
    def __init__(out self, var value: Ok[Self.T]):
        """Store a success; an `Ok` converts to a Result wherever the Result type is known.

        Args:
            value: The success, moved in.
        """
        self._value = value^

    @always_inline
    @implicit
    def __init__(out self, var error: Err[Self.E]):
        """An `Err` converts to a Result wherever the Result type is known."""
        self._value = error^

    @always_inline
    def _ok(ref self) -> ref[self._value] Ok[Self.T]:
        """The `Ok` constructor; the Result must be `Ok`."""
        return self._value.unsafe_get[Ok[Self.T]]()

    @always_inline
    def _err(ref self) -> ref[self._value] Err[Self.E]:
        """The `Err` constructor; the Result must be `Err`."""
        return self._value.unsafe_get[Err[Self.E]]()

    @always_inline
    def _take_ok(deinit self) -> Self.T:
        """Consume an `Ok` Result and return its value."""
        return self._value^.unsafe_unwrap[Ok[Self.T]]().into_payload()

    @always_inline
    def _take_err(deinit self) -> Self.E:
        """Consume an `Err` Result and return its error."""
        return self._value^.unsafe_unwrap[Err[Self.E]]().into_payload()

    @always_inline
    def is_ok(self) -> Bool:
        """Whether the Result holds `Ok`.

        Returns:
            True for `Ok`, False for `Err`.
        """
        return self._value.isa[Ok[Self.T]]()

    @always_inline
    def is_err(self) -> Bool:
        """Whether the Result holds `Err`.

        Returns:
            True for `Err`, False for `Ok`.
        """
        return self._value.isa[Err[Self.E]]()

    def raise_on_err(deinit self) raises Self.E -> Self.T:
        """Consume the Result and return its value, or raise its stored error.

        Returns:
            The success value, moved out.

        Raises:
            The stored error, with its original type.
        """
        if self.is_ok():
            return self^._take_ok()
        raise self^._take_err()

    # Folds borrow the Result, or consume it with `fold_owned`, and call the
    # callback for its case with the payload. Native callbacks are borrowed;
    # library callbacks are borrowed or, in the `_once` forms, consumed.
    def fold[R: Movable & Deinitable, //,
             F: def(Self.T) -> R, G: def(Self.E) -> R](
        self, on_ok: F, on_err: G
    ) -> R:
        """Call `on_ok` with the value or `on_err` with the error, borrowed, and return its result.

        Exactly one callback runs. The two callbacks return the same type; when
        both raise, they raise one error type, or one of them nothing.

        Parameters:
            R: The result type of both callbacks.
            F: The success callback's type: a plain function or a closure.
            G: The error callback's type: a plain function or a closure.

        Args:
            on_ok: The callback for `Ok`, borrowed.
            on_err: The callback for `Err`, borrowed.

        Returns:
            The result of the callback that ran.
        """
        if self.is_ok():
            return on_ok(self._ok().value)
        return on_err(self._err().value)

    def fold_owned[R: Movable & Deinitable, //,
                   F: def(var Self.T) -> R, G: def(var Self.E) -> R](
        deinit self, on_ok: F, on_err: G
    ) -> R:
        """Consume the Result and move its value or error into the matching callback.

        Parameters:
            R: The result type of both callbacks.
            F: The success callback's type: a plain function or a closure.
            G: The error callback's type: a plain function or a closure.

        Args:
            on_ok: The callback for `Ok`, borrowed; it receives the value.
            on_err: The callback for `Err`, borrowed; it receives the error.

        Returns:
            The result of the callback that ran.
        """
        def invoke_ok(var payload: Self.T, function: F) raises Never capturing -> R:
            return function(payload^)
        def invoke_err(var payload: Self.E, function: G) raises Never capturing -> R:
            return function(payload^)
        return _fold_result_owned[Self.T, Self.E, R, Never, Never, Never,
            Pointer[F, origin_of(on_ok)], Pointer[G, origin_of(on_err)],
            _borrowed_transform[Self.T, R, Never, F, origin_of(on_ok), invoke_ok],
            _borrowed_transform[Self.E, R, Never, G, origin_of(on_err), invoke_err]](
                self^, Pointer(to=on_ok), Pointer(to=on_err))

    def fold[R: Movable & Deinitable, X: Movable & Deinitable, //,
             F: def(Self.T) raises X -> R,
             G: def(Self.E) -> R](
        self, on_ok: F, on_err: G
    ) raises X -> R:
        """Fold with a raising success callback."""
        if self.is_ok():
            return on_ok(self._ok().value)
        return on_err(self._err().value)

    def fold[R: Movable & Deinitable, X: Movable & Deinitable, //,
             F: def(Self.T) -> R,
             G: def(Self.E) raises X -> R](
        self, on_ok: F, on_err: G
    ) raises X -> R:
        """Fold with a raising error callback."""
        if self.is_ok():
            return on_ok(self._ok().value)
        return on_err(self._err().value)

    def fold[R: Movable & Deinitable, X: Movable & Deinitable, Y: Movable & Deinitable, //,
             F: def(Self.T) raises X -> R,
             G: def(Self.E) raises Y -> R](
        self, on_ok: F, on_err: G
    ) raises _ResultFailure[X, Y] -> R where X == Never or Y == Never or X == Y:
        """Fold with two raising callbacks, which raise one error type."""
        comptime assert _ErrorCompatible[_ResultFailure[X, Y], X] and _ErrorCompatible[_ResultFailure[X, Y], Y]
        if self.is_ok():
            try:
                return on_ok(self._ok().value)
            except error:
                _propagate_error[_ResultFailure[X, Y]](error^)
        try:
            return on_err(self._err().value)
        except error:
            _propagate_error[_ResultFailure[X, Y]](error^)

    def fold_owned[R: Movable & Deinitable, X: Movable & Deinitable, //,
             F: def(var Self.T) raises X -> R,
             G: def(var Self.E) -> R](
        deinit self, on_ok: F, on_err: G
    ) raises X -> R:
        """Consuming fold with a raising success callback."""
        def invoke_ok(var payload: Self.T, function: F) raises X capturing -> R:
            return function(payload^)
        def invoke_err(var payload: Self.E, function: G) raises Never capturing -> R:
            return function(payload^)
        return _fold_result_owned[Self.T, Self.E, R, X, X, Never,
            Pointer[F, origin_of(on_ok)], Pointer[G, origin_of(on_err)],
            _borrowed_transform[Self.T, R, X, F, origin_of(on_ok), invoke_ok],
            _borrowed_transform[Self.E, R, Never, G, origin_of(on_err), invoke_err]](
                self^, Pointer(to=on_ok), Pointer(to=on_err))

    def fold_owned[R: Movable & Deinitable, X: Movable & Deinitable, //,
             F: def(var Self.T) -> R,
             G: def(var Self.E) raises X -> R](
        deinit self, on_ok: F, on_err: G
    ) raises X -> R:
        """Consuming fold with a raising error callback."""
        def invoke_ok(var payload: Self.T, function: F) raises Never capturing -> R:
            return function(payload^)
        def invoke_err(var payload: Self.E, function: G) raises X capturing -> R:
            return function(payload^)
        return _fold_result_owned[Self.T, Self.E, R, X, Never, X,
            Pointer[F, origin_of(on_ok)], Pointer[G, origin_of(on_err)],
            _borrowed_transform[Self.T, R, Never, F, origin_of(on_ok), invoke_ok],
            _borrowed_transform[Self.E, R, X, G, origin_of(on_err), invoke_err]](
                self^, Pointer(to=on_ok), Pointer(to=on_err))

    def fold_owned[R: Movable & Deinitable, X: Movable & Deinitable, Y: Movable & Deinitable, //,
             F: def(var Self.T) raises X -> R,
             G: def(var Self.E) raises Y -> R](
        deinit self, on_ok: F, on_err: G
    ) raises _ResultFailure[X, Y] -> R where X == Never or Y == Never or X == Y:
        """Consuming fold with two raising callbacks, which raise one error type."""
        def invoke_ok(var payload: Self.T, function: F) raises X capturing -> R:
            return function(payload^)
        def invoke_err(var payload: Self.E, function: G) raises Y capturing -> R:
            return function(payload^)
        return _fold_result_owned[Self.T, Self.E, R, _ResultFailure[X, Y], X, Y,
            Pointer[F, origin_of(on_ok)], Pointer[G, origin_of(on_err)],
            _borrowed_transform[Self.T, R, X, F, origin_of(on_ok), invoke_ok],
            _borrowed_transform[Self.E, R, Y, G, origin_of(on_err), invoke_err]](
                self^, Pointer(to=on_ok), Pointer(to=on_err))

    def fold[F: BorrowCallable, G: BorrowCallable](self, on_ok: F, on_err: G
    ) raises _ResultFailure[F.Failure, G.Failure] -> F.Result where F.Payload == Self.T and G.Payload == Self.E and F.Result == G.Result and (F.Failure == Never or G.Failure == Never or F.Failure == G.Failure):
        """Fold with two `BorrowCallable` handlers."""
        comptime Z = _ResultFailure[F.Failure, G.Failure]
        comptime assert _ErrorCompatible[Z, F.Failure] and _ErrorCompatible[Z, G.Failure]
        if self.is_ok():
            return invoke_borrowed[Z](self._ok().value, on_ok)
        return rebind_var[F.Result](invoke_borrowed[Z](self._err().value, on_err))

    def fold_owned[F: Unary, G: Unary](deinit self, on_ok: F, on_err: G
    ) raises _ResultFailure[F.Error, G.Error] -> F.Out where F.Arg == Self.T and G.Arg == Self.E and F.Out == G.Out and (F.Error == Never or G.Error == Never or F.Error == G.Error):
        """Consuming fold with two library `Unary` handlers."""
        def invoke_ok(var payload: Self.T, function: F) raises F.Error capturing -> F.Out:
            return function.call(rebind_var[F.Arg](payload^))
        def invoke_err(var payload: Self.E, function: G) raises G.Error capturing -> F.Out:
            return rebind_var[F.Out](function.call(rebind_var[G.Arg](payload^)))
        return _fold_result_owned[Self.T, Self.E, F.Out, _ResultFailure[F.Error, G.Error], F.Error, G.Error,
            Pointer[F, origin_of(on_ok)], Pointer[G, origin_of(on_err)],
            _borrowed_transform[Self.T, F.Out, F.Error, F, origin_of(on_ok), invoke_ok],
            _borrowed_transform[Self.E, F.Out, G.Error, G, origin_of(on_err), invoke_err]](
                self^, Pointer(to=on_ok), Pointer(to=on_err))

    def fold_once[F: BorrowOnceCallable, G: BorrowOnceCallable](self, var on_ok: F, var on_err: G
    ) raises _ResultFailure[F.Failure, G.Failure] -> F.Result where F.Payload == Self.T and G.Payload == Self.E and F.Result == G.Result and (F.Failure == Never or G.Failure == Never or F.Failure == G.Failure):
        """Fold with two consuming handlers: borrow the payload, and call only the selected handler.

        Both handlers move in; the one that does not run is destroyed. No
        `Copyable` requirement is added. A result may refer to owners that
        outlive the call, never into a consumed handler.

        Parameters:
            F: The success handler's type, a `BorrowOnceCallable` taking `T`.
            G: The error handler's type, a `BorrowOnceCallable` taking `E`.

        Args:
            on_ok: The handler for `Ok`, consumed.
            on_err: The handler for `Err`, consumed.

        Returns:
            The result of the handler that ran.

        Raises:
            The error of the handler that ran; both raise one error type, or
            one of them nothing.
        """
        comptime Z = _ResultFailure[F.Failure, G.Failure]
        comptime assert _ErrorCompatible[Z, F.Failure] and _ErrorCompatible[Z, G.Failure]
        if self.is_ok():
            return invoke_borrowed_once[Z](self._ok().value, on_ok^)
        return rebind_var[F.Result](invoke_borrowed_once[Z](self._err().value, on_err^))

    def fold_owned_once[F: OnceUnary, G: OnceUnary](deinit self, var on_ok: F, var on_err: G
    ) raises _ResultFailure[F.Error, G.Error] -> F.Out where F.Arg == Self.T and G.Arg == Self.E and F.Out == G.Out and (F.Error == Never or G.Error == Never or F.Error == G.Error):
        """Consume the Result and two consuming handlers, and move the payload into the selected one.

        Parameters:
            F: The success handler's type, a `OnceUnary` taking `T`.
            G: The error handler's type, a `OnceUnary` taking `E`.

        Args:
            on_ok: The handler for `Ok`, consumed.
            on_err: The handler for `Err`, consumed.

        Returns:
            The result of the handler that ran.

        Raises:
            The error of the handler that ran; both raise one error type, or
            one of them nothing.
        """
        return _fold_result_owned[Self.T, Self.E, F.Out, _ResultFailure[F.Error, G.Error], F.Error, G.Error, F, G,
            _call_transform[Self.T, F], _call_transform[Self.E, G, F.Out]](self^, on_ok^, on_err^)

    # Transformations consume the Result. Native callbacks are borrowed and
    # library Unary callbacks move in; each is called at most once, and both
    # enter the shared owned transformation below the struct.
    def map[U: Movable & Deinitable, //, F: def(var Self.T) -> U](deinit self, function: F) -> Result[U, Self.E]:
        """Transform the success value; an error passes through and `function` does not run.

        `map` keeps a returned `Result` as nested data; `flat_map` sequences.

        Parameters:
            U: The new success type.
            F: The callback's type: a plain function or a closure.

        Args:
            function: The callback, borrowed; it runs at most once.

        Returns:
            `Ok(function(value))`, or the original `Err`.
        """
        def apply(var payload: Self.T, callback: F) raises Never capturing -> U:
            return callback(payload^)
        return _transform_result[Self.T, Self.E, U, Self.E, Never, True, True, Self.T, U, F, apply](self^, function)

    def map[U: Movable & Deinitable, //, X: Movable & Deinitable, F: def(var Self.T) raises X -> U](
        deinit self, function: F
    ) raises X -> Result[U, Self.E]:
        """Raising form of `map`; the callback's error type is kept."""
        def apply(var payload: Self.T, callback: F) raises X capturing -> U:
            return callback(payload^)
        return _transform_result[Self.T, Self.E, U, Self.E, X, True, True, Self.T, U, F, apply](self^, function)

    def map[F: _UnaryViewable, o: ImmOrigin](deinit self, ref[o] function: F
    ) raises F._View[o].Error -> Result[F._View[o].Out, Self.E] where F._View[o].Arg == Self.T:
        """Apply a borrowed callable view to the success value."""
        return self^.map(function._unary_view())

    def map[F: UnaryContract & Movable & Deinitable](deinit self, var function: F
    ) raises F.Error -> Result[F.Out, Self.E] where F.Arg == Self.T:
        """Transform the success value with a library unary callback."""
        return _result_transform[Self.T, Self.E, F.Out, Self.E, F, True, True](function^, self^)

    def flat_map[U: Movable & Deinitable, //, F: def(var Self.T) -> Result[U, Self.E]](
        deinit self, function: F
    ) -> Result[U, Self.E]:
        """Continue with the Result the callback returns; an error passes through.

        The callback's stored error type must be exactly `E`; combine different
        error types with `map_err` first.

        Parameters:
            U: The new success type.
            F: The callback's type: a plain function or a closure returning `Result[U, E]`.

        Args:
            function: The callback, borrowed; it runs at most once.

        Returns:
            `function(value)`, or the original `Err`.
        """
        def apply(var payload: Self.T, callback: F) raises Never capturing -> Result[U, Self.E]:
            return callback(payload^)
        return _transform_result[Self.T, Self.E, U, Self.E, Never, True, False, Self.T, Result[U, Self.E], F, apply](
            self^, function)

    def flat_map[U: Movable & Deinitable, //, X: Movable & Deinitable, F: def(var Self.T) raises X -> Result[U, Self.E]](
        deinit self, function: F
    ) raises X -> Result[U, Self.E]:
        """Raising form of `flat_map`; the callback's error type is kept."""
        def apply(var payload: Self.T, callback: F) raises X capturing -> Result[U, Self.E]:
            return callback(payload^)
        return _transform_result[Self.T, Self.E, U, Self.E, X, True, False, Self.T, Result[U, Self.E], F, apply](
            self^, function)

    def flat_map[F: _UnaryViewable, o: ImmOrigin](deinit self, ref[o] function: F
    ) raises F._View[o].Error -> F._View[o].Out where F._View[o].Arg == Self.T and F._View[o].Out == Result[downcast[F._View[o].Out, _ResultType].Value, Self.E]:
        """Apply a borrowed callable view to the success value."""
        return self^.flat_map(function._unary_view())

    def flat_map[F: UnaryContract & Movable & Deinitable](deinit self, var function: F
    ) raises F.Error -> F.Out where F.Arg == Self.T:
        """Continue with a library unary callback returning a Result."""
        comptime U = downcast[F.Out, _ResultType].Value
        comptime assert F.Out == Result[U, Self.E], "flat_map: callback must return a Result with the same error type"
        return rebind_var[F.Out](_result_transform[Self.T, Self.E, U, Self.E, F, True, False](function^, self^))

    def map_err[U: Movable & Deinitable, //, F: def(var Self.E) -> U](deinit self, function: F) -> Result[Self.T, U]:
        """Transform the stored error; a success passes through and `function` does not run.

        Parameters:
            U: The new error type.
            F: The callback's type: a plain function or a closure.

        Args:
            function: The callback, borrowed; it runs at most once.

        Returns:
            `Err(function(error))`, or the original `Ok`.
        """
        def apply(var payload: Self.E, callback: F) raises Never capturing -> U:
            return callback(payload^)
        return _transform_result[Self.T, Self.E, Self.T, U, Never, False, True, Self.E, U, F, apply](self^, function)

    def map_err[U: Movable & Deinitable, //, X: Movable & Deinitable, F: def(var Self.E) raises X -> U](
        deinit self, function: F
    ) raises X -> Result[Self.T, U]:
        """Raising form of `map_err`; the callback's error type is kept."""
        def apply(var payload: Self.E, callback: F) raises X capturing -> U:
            return callback(payload^)
        return _transform_result[Self.T, Self.E, Self.T, U, X, False, True, Self.E, U, F, apply](self^, function)

    def map_err[F: UnaryContract & Movable & Deinitable](deinit self, var function: F
    ) raises F.Error -> Result[Self.T, F.Out] where F.Arg == Self.E:
        """Transform the error with a library unary callback."""
        return _result_transform[Self.T, Self.E, Self.T, F.Out, F, False, True](function^, self^)

    def or_else[U: Movable & Deinitable, //, F: def(var Self.E) -> Result[Self.T, U]](
        deinit self, function: F
    ) -> Result[Self.T, U]:
        """Recover from the stored error with the Result the callback returns; a success passes through.

        The callback's success type must be exactly `T`.

        Parameters:
            U: The new error type.
            F: The callback's type: a plain function or a closure returning `Result[T, U]`.

        Args:
            function: The callback, borrowed; it runs at most once.

        Returns:
            `function(error)`, or the original `Ok`.
        """
        def apply(var payload: Self.E, callback: F) raises Never capturing -> Result[Self.T, U]:
            return callback(payload^)
        return _transform_result[Self.T, Self.E, Self.T, U, Never, False, False, Self.E, Result[Self.T, U], F, apply](
            self^, function)

    def or_else[U: Movable & Deinitable, //, X: Movable & Deinitable, F: def(var Self.E) raises X -> Result[Self.T, U]](
        deinit self, function: F
    ) raises X -> Result[Self.T, U]:
        """Raising form of `or_else`; the callback's error type is kept."""
        def apply(var payload: Self.E, callback: F) raises X capturing -> Result[Self.T, U]:
            return callback(payload^)
        return _transform_result[Self.T, Self.E, Self.T, U, X, False, False, Self.E, Result[Self.T, U], F, apply](
            self^, function)

    def or_else[F: UnaryContract & Movable & Deinitable](deinit self, var function: F
    ) raises F.Error -> F.Out where F.Arg == Self.E:
        """Recover with a library unary callback returning a Result."""
        comptime U = downcast[F.Out, _ResultType].Error
        comptime assert F.Out == Result[Self.T, U], "or_else: callback must retain the success type"
        return rebind_var[F.Out](_result_transform[Self.T, Self.E, Self.T, U, F, False, False](function^, self^))




    # --- Result combinators (generated) ---
    # Generated by scripts/generate_result_syntax.py; execution stays in Result and shared callable adapters.

    def flat_tap[C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Result[Self.T, Self.E] where C.Payload == Self.T:
        """Sequence a borrowed Result projection and retain the original success value.

        The projection runs only on Ok. Its Err replaces the success; its Ok payload is discarded. The original payload is moved, never copied. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Sequence a borrowed Result projection and retain the original success value.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return self^.flat_map(_ResultRetain[Self.T, Self.E, C, False](function^))

    def flat_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Result[Self.T, Self.E] where P == Self.T:
        """Sequence a borrowed Result projection and retain the original success value."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        return self^.flat_tap(_NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=function)))

    def flat_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Result[Self.T, Self.E] where P == Self.T:
        """Sequence a borrowed Result projection and retain the original success value."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        return self^.flat_tap(_NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=function)))

    def flat_pair_with[C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Result[Tuple[Self.T, downcast[C.Result, _ResultType].Value], Self.E] where C.Payload == Self.T:
        """Sequence a borrowed Result projection and retain both success values.

        The projection runs only on Ok. Its Err replaces the success; its Ok payload is paired with the moved original. Neither payload needs Copyable. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Sequence a borrowed Result projection and retain both success values.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return self^.flat_map(_ResultRetain[Self.T, Self.E, C, True](function^))

    def flat_pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Result[Tuple[Self.T, downcast[R, _ResultType].Value], Self.E] where P == Self.T:
        """Sequence a borrowed Result projection and retain both success values."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        return self^.flat_pair_with(_NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=function)))

    def flat_pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Result[Tuple[Self.T, downcast[R, _ResultType].Value], Self.E] where P == Self.T:
        """Sequence a borrowed Result projection and retain both success values."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        return self^.flat_pair_with(_NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=function)))

    def followed_by[C: ThunkContract & Movable & Deinitable](deinit self, var function: C) raises C.Error -> C.Out:
        """On success, call a zero-argument factory and return its Result.

        The factory runs at most once and is skipped on Err. The preceding success payload is discarded. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            On success, call a zero-argument factory and return its Result.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return self^.flat_map(_IgnoreInput[Self.T, C](function^))

    def followed_by[R: Movable & Deinitable, o: ImmOrigin, //, C: _Thunk[R]](deinit self, ref[o] function: C) raises Never -> R:
        """On success, call a zero-argument factory and return its Result."""
        def invoke_factory(factory: C, payload: Self.T) raises Never capturing -> R:
            return factory()
        return self^.flat_map(_BorrowedUnary[Self.T, _NativeBorrowRef[Self.T, R, Never, C, False, o, True, invoke_factory]](_NativeBorrowRef[Self.T, R, Never, C, False, o, True, invoke_factory](Pointer(to=function))))

    def followed_by[R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises X -> R:
        """On success, call a zero-argument factory and return its Result."""
        def invoke_factory(factory: C, payload: Self.T) raises X capturing -> R:
            return factory()
        return self^.flat_map(_BorrowedUnary[Self.T, _NativeBorrowRef[Self.T, R, X, C, True, o, True, invoke_factory]](_NativeBorrowRef[Self.T, R, X, C, True, o, True, invoke_factory](Pointer(to=function))))

    def before[C: ThunkContract & Movable & Deinitable](deinit self, var function: C) raises C.Error -> Result[Self.T, Self.E]:
        """On success, call a zero-argument factory and retain the original value.

        The factory runs at most once and is skipped on Err. Its Err replaces the success; its Ok payload is discarded. The original payload is moved, never copied. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            On success, call a zero-argument factory and retain the original value.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return self^.flat_map(_ResultRetain[Self.T, Self.E, _IgnoreInput[Self.T, C], False](_IgnoreInput[Self.T, C](function^)))

    def before[R: Movable & Deinitable, o: ImmOrigin, //, C: _Thunk[R]](deinit self, ref[o] function: C) raises Never -> Result[Self.T, Self.E]:
        """On success, call a zero-argument factory and retain the original value."""
        def invoke_factory(factory: C, payload: Self.T) raises Never capturing -> R:
            return factory()
        return self^.flat_map(_ResultRetain[Self.T, Self.E, _NativeBorrowRef[Self.T, R, Never, C, False, o, True, invoke_factory], False](_NativeBorrowRef[Self.T, R, Never, C, False, o, True, invoke_factory](Pointer(to=function))))

    def before[R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises X -> Result[Self.T, Self.E]:
        """On success, call a zero-argument factory and retain the original value."""
        def invoke_factory(factory: C, payload: Self.T) raises X capturing -> R:
            return factory()
        return self^.flat_map(_ResultRetain[Self.T, Self.E, _NativeBorrowRef[Self.T, R, X, C, True, o, True, invoke_factory], False](_NativeBorrowRef[Self.T, R, X, C, True, o, True, invoke_factory](Pointer(to=function))))

    def ensure[C: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C, var make_error: G) raises _CommonError[C.Failure, G.Failure] -> Result[Self.T, Self.E] where C.Payload == Self.T and C.Result == Bool and G.Payload == Self.T and G.Result == Self.E:
        """Keep an accepted success or construct a stored error from its borrowed value.

        The predicate runs only on Ok; the error factory runs only when the predicate returns False. Both borrow the success payload. The original Err passes through unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.
            G: The selected continuation type, retaining its receiver and native error.

        Args:
            predicate: The consumed borrowing predicate returning Bool.
            make_error: The consumed borrowing factory returning the stored error type.

        Returns:
            Keep an accepted success or construct a stored error from its borrowed value.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return _conditional_result[Self.T, Self.E, C, _BorrowedUnary[Self.T, G], Self.T, G.Result, G.Failure, _CommonError[C.Failure, G.Failure], True, True, False, _call_transform[Self.T, _BorrowedUnary[Self.T, G]]](self^, predicate^, _BorrowedUnary[Self.T, G](make_error^))

    def ensure[C: BorrowCallContract & Movable & Deinitable, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, G: _Borrowing[Q, S]](deinit self, var predicate: C, ref[q] make_error: G) raises _CommonError[C.Failure, Never] -> Result[Self.T, Self.E] where C.Payload == Self.T and C.Result == Bool and Q == Self.T and S == Self.E:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        def invoke_1(function: G, payload: Q) raises Never capturing -> S:
            return function(payload)
        return self^.ensure(predicate^, _NativeBorrowRef[Q, S, Never, G, False, q, True, invoke_1](Pointer(to=make_error)))

    def ensure[C: BorrowCallContract & Movable & Deinitable, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y]](deinit self, var predicate: C, ref[q] make_error: G) raises _CommonError[C.Failure, Y] -> Result[Self.T, Self.E] where C.Payload == Self.T and C.Result == Bool and Q == Self.T and S == Self.E:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        def invoke_1(function: G, payload: Q) raises Y capturing -> S:
            return function(payload)
        return self^.ensure(predicate^, _NativeBorrowRef[Q, S, Y, G, True, q, True, invoke_1](Pointer(to=make_error)))

    def ensure[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: BorrowCallContract & Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, ref[o] predicate: C, var make_error: G) raises _CommonError[Never, G.Failure] -> Result[Self.T, Self.E] where P == Self.T and R == Bool and G.Payload == Self.T and G.Result == Self.E:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        return self^.ensure(_NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=predicate)), make_error^)

    def ensure[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], G: _Borrowing[Q, S]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[Never, Never] -> Result[Self.T, Self.E] where P == Self.T and R == Bool and Q == Self.T and S == Self.E:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        def invoke_1(function: G, payload: Q) raises Never capturing -> S:
            return function(payload)
        return self^.ensure(_NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Never, G, False, q, True, invoke_1](Pointer(to=make_error)))

    def ensure[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[Never, Y] -> Result[Self.T, Self.E] where P == Self.T and R == Bool and Q == Self.T and S == Self.E:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        def invoke_1(function: G, payload: Q) raises Y capturing -> S:
            return function(payload)
        return self^.ensure(_NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Y, G, True, q, True, invoke_1](Pointer(to=make_error)))

    def ensure[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: BorrowCallContract & Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] predicate: C, var make_error: G) raises _CommonError[X, G.Failure] -> Result[Self.T, Self.E] where P == Self.T and R == Bool and G.Payload == Self.T and G.Result == Self.E:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        return self^.ensure(_NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=predicate)), make_error^)

    def ensure[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], G: _Borrowing[Q, S]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[X, Never] -> Result[Self.T, Self.E] where P == Self.T and R == Bool and Q == Self.T and S == Self.E:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        def invoke_1(function: G, payload: Q) raises Never capturing -> S:
            return function(payload)
        return self^.ensure(_NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Never, G, False, q, True, invoke_1](Pointer(to=make_error)))

    def ensure[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[X, Y] -> Result[Self.T, Self.E] where P == Self.T and R == Bool and Q == Self.T and S == Self.E:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        def invoke_1(function: G, payload: Q) raises Y capturing -> S:
            return function(payload)
        return self^.ensure(_NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Y, G, True, q, True, invoke_1](Pointer(to=make_error)))

    def recover[C: UnaryContract & Movable & Deinitable](deinit self, var function: C) raises C.Error -> Result[Self.T, Self.E] where C.Arg == Self.E and C.Out == Self.T:
        """Recover a stored error as a success, retaining the Result error type.

        The callback consumes the error and returns the original success type. Ok passes through unchanged. This returns Result[T, E], not an unwrapped value. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Recover a stored error as a success, retaining the Result error type.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return _result_transform[Self.T, Self.E, Self.T, Self.E, C, False, True, True](function^, self^)

    def recover[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: _Unary[A, R]](deinit self, ref[o] function: C) raises Never -> Result[Self.T, Self.E] where A == Self.E and R == Self.T:
        """Recover a stored error as a success, retaining the Result error type."""
        def invoke_recovery(var payload: Self.E, callback: C) raises Never capturing -> Self.T:
            return rebind_var[Self.T](callback(rebind_var[A](payload^)))
        return _transform_result[Self.T, Self.E, Self.T, Self.E, Never, False, True, Self.E, Self.T, C, invoke_recovery, True](self^, function)

    def recover[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingUnary[A, R, X]](deinit self, ref[o] function: C) raises X -> Result[Self.T, Self.E] where A == Self.E and R == Self.T:
        """Recover a stored error as a success, retaining the Result error type."""
        def invoke_recovery(var payload: Self.E, callback: C) raises X capturing -> Self.T:
            return rebind_var[Self.T](callback(rebind_var[A](payload^)))
        return _transform_result[Self.T, Self.E, Self.T, Self.E, X, False, True, Self.E, Self.T, C, invoke_recovery, True](self^, function)

    def tap_err[C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Result[Self.T, Self.E] where C.Payload == Self.E:
        """Inspect a borrowed stored error and retain the Result.

        The inspector runs only on Err. Its return value is discarded; the error is moved back unchanged. Ok passes through without inspection. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Inspect a borrowed stored error and retain the Result.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return self^.map_err(_ObserveOnce[Self.E, C, False](function^))

    def tap_err[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Result[Self.T, Self.E] where P == Self.E:
        """Inspect a borrowed stored error and retain the Result."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        return self^.tap_err(_NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=function)))

    def tap_err[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Result[Self.T, Self.E] where P == Self.E:
        """Inspect a borrowed stored error and retain the Result."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        return self^.tap_err(_NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=function)))

    def recover_if[C: BorrowCallContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var predicate: C, var function: G) raises _CommonError[C.Failure, G.Error] -> Result[Self.T, Self.E] where C.Payload == Self.E and C.Result == Bool and G.Arg == Self.E and G.Out == Self.T:
        """Recover a matching stored error as a success.

        Only Err runs the borrowing predicate. On True, the recovery consumes the error and returns the success type. On False, the original error remains. The stored error type stays unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.
            G: The selected continuation type, retaining its receiver and native error.

        Args:
            predicate: The consumed borrowing predicate returning Bool.
            function: The recovery, consumed and called only for matching errors; it consumes the stored error.

        Returns:
            Recover a matching stored error as a success.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return _conditional_result[Self.T, Self.E, C, G, Self.E, G.Out, G.Error, _CommonError[C.Failure, G.Error], False, True, True, _call_transform[Self.E, G]](self^, predicate^, function^)

    def recover_if[C: BorrowCallContract & Movable & Deinitable, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: _Unary[Q, S]](deinit self, var predicate: C, ref[q] function: G) raises C.Failure -> Result[Self.T, Self.E] where C.Payload == Self.E and C.Result == Bool and Q == Self.E and S == Self.T:
        """Recover a matching stored error as a success."""
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, C, Pointer[G, q], Q, S, Never, C.Failure, False, True, True, invoke_recovery](self^, predicate^, Pointer(to=function))

    def recover_if[C: BorrowCallContract & Movable & Deinitable, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, var predicate: C, ref[q] function: G) raises _CommonError[C.Failure, Y] -> Result[Self.T, Self.E] where C.Payload == Self.E and C.Result == Bool and Q == Self.E and S == Self.T:
        """Recover a matching stored error as a success."""
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, C, Pointer[G, q], Q, S, Y, _CommonError[C.Failure, Y], False, True, True, invoke_recovery](self^, predicate^, Pointer(to=function))

    def recover_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[Never, G.Error] -> Result[Self.T, Self.E] where P == Self.E and R == Bool and G.Arg == Self.E and G.Out == Self.T:
        """Recover a matching stored error as a success."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        return self^.recover_if(_NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=predicate)), function^)

    def recover_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises Never -> Result[Self.T, Self.E] where P == Self.E and R == Bool and Q == Self.E and S == Self.T:
        """Recover a matching stored error as a success."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, _NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0], Pointer[G, q], Q, S, Never, Never, False, True, True, invoke_recovery](self^, _NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=predicate)), Pointer(to=function))

    def recover_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[Never, Y] -> Result[Self.T, Self.E] where P == Self.E and R == Bool and Q == Self.E and S == Self.T:
        """Recover a matching stored error as a success."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, _NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0], Pointer[G, q], Q, S, Y, _CommonError[Never, Y], False, True, True, invoke_recovery](self^, _NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=predicate)), Pointer(to=function))

    def recover_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[X, G.Error] -> Result[Self.T, Self.E] where P == Self.E and R == Bool and G.Arg == Self.E and G.Out == Self.T:
        """Recover a matching stored error as a success."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        return self^.recover_if(_NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=predicate)), function^)

    def recover_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises X -> Result[Self.T, Self.E] where P == Self.E and R == Bool and Q == Self.E and S == Self.T:
        """Recover a matching stored error as a success."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, _NativeBorrowRef[P, R, X, C, True, o, True, invoke_0], Pointer[G, q], Q, S, Never, X, False, True, True, invoke_recovery](self^, _NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=predicate)), Pointer(to=function))

    def recover_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[X, Y] -> Result[Self.T, Self.E] where P == Self.E and R == Bool and Q == Self.E and S == Self.T:
        """Recover a matching stored error as a success."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, _NativeBorrowRef[P, R, X, C, True, o, True, invoke_0], Pointer[G, q], Q, S, Y, _CommonError[X, Y], False, True, True, invoke_recovery](self^, _NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=predicate)), Pointer(to=function))

    def or_else_if[C: BorrowCallContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var predicate: C, var function: G) raises _CommonError[C.Failure, G.Error] -> Result[Self.T, Self.E] where C.Payload == Self.E and C.Result == Bool and G.Arg == Self.E and G.Out == Result[Self.T, Self.E]:
        """Continue a matching stored error with a Result.

        Only Err runs the borrowing predicate. On True, the recovery consumes the error and returns Result[T, E]; on False, the original error remains. Both success and stored error types stay unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.
            G: The selected continuation type, retaining its receiver and native error.

        Args:
            predicate: The consumed borrowing predicate returning Bool.
            function: The recovery, consumed and called only for matching errors; it consumes the stored error.

        Returns:
            Continue a matching stored error with a Result.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return _conditional_result[Self.T, Self.E, C, G, Self.E, G.Out, G.Error, _CommonError[C.Failure, G.Error], False, False, True, _call_transform[Self.E, G]](self^, predicate^, function^)

    def or_else_if[C: BorrowCallContract & Movable & Deinitable, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: _Unary[Q, S]](deinit self, var predicate: C, ref[q] function: G) raises C.Failure -> Result[Self.T, Self.E] where C.Payload == Self.E and C.Result == Bool and Q == Self.E and S == Result[Self.T, Self.E]:
        """Continue a matching stored error with a Result."""
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, C, Pointer[G, q], Q, S, Never, C.Failure, False, False, True, invoke_recovery](self^, predicate^, Pointer(to=function))

    def or_else_if[C: BorrowCallContract & Movable & Deinitable, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, var predicate: C, ref[q] function: G) raises _CommonError[C.Failure, Y] -> Result[Self.T, Self.E] where C.Payload == Self.E and C.Result == Bool and Q == Self.E and S == Result[Self.T, Self.E]:
        """Continue a matching stored error with a Result."""
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, C, Pointer[G, q], Q, S, Y, _CommonError[C.Failure, Y], False, False, True, invoke_recovery](self^, predicate^, Pointer(to=function))

    def or_else_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[Never, G.Error] -> Result[Self.T, Self.E] where P == Self.E and R == Bool and G.Arg == Self.E and G.Out == Result[Self.T, Self.E]:
        """Continue a matching stored error with a Result."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        return self^.or_else_if(_NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=predicate)), function^)

    def or_else_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises Never -> Result[Self.T, Self.E] where P == Self.E and R == Bool and Q == Self.E and S == Result[Self.T, Self.E]:
        """Continue a matching stored error with a Result."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, _NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0], Pointer[G, q], Q, S, Never, Never, False, False, True, invoke_recovery](self^, _NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=predicate)), Pointer(to=function))

    def or_else_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[Never, Y] -> Result[Self.T, Self.E] where P == Self.E and R == Bool and Q == Self.E and S == Result[Self.T, Self.E]:
        """Continue a matching stored error with a Result."""
        def invoke_0(function: C, payload: P) raises Never capturing -> R:
            return function(payload)
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, _NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0], Pointer[G, q], Q, S, Y, _CommonError[Never, Y], False, False, True, invoke_recovery](self^, _NativeBorrowRef[P, R, Never, C, False, o, True, invoke_0](Pointer(to=predicate)), Pointer(to=function))

    def or_else_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[X, G.Error] -> Result[Self.T, Self.E] where P == Self.E and R == Bool and G.Arg == Self.E and G.Out == Result[Self.T, Self.E]:
        """Continue a matching stored error with a Result."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        return self^.or_else_if(_NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=predicate)), function^)

    def or_else_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises X -> Result[Self.T, Self.E] where P == Self.E and R == Bool and Q == Self.E and S == Result[Self.T, Self.E]:
        """Continue a matching stored error with a Result."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, _NativeBorrowRef[P, R, X, C, True, o, True, invoke_0], Pointer[G, q], Q, S, Never, X, False, False, True, invoke_recovery](self^, _NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=predicate)), Pointer(to=function))

    def or_else_if[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[X, Y] -> Result[Self.T, Self.E] where P == Self.E and R == Bool and Q == Self.E and S == Result[Self.T, Self.E]:
        """Continue a matching stored error with a Result."""
        def invoke_0(function: C, payload: P) raises X capturing -> R:
            return function(payload)
        def invoke_recovery(var payload: Q, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](payload^)
        return _conditional_result[Self.T, Self.E, _NativeBorrowRef[P, R, X, C, True, o, True, invoke_0], Pointer[G, q], Q, S, Y, _CommonError[X, Y], False, False, True, invoke_recovery](self^, _NativeBorrowRef[P, R, X, C, True, o, True, invoke_0](Pointer(to=predicate)), Pointer(to=function))

    def flat_tap_err[C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Result[Self.T, Self.E] where C.Payload == Self.E and C.Result == Result[downcast[C.Result, _ResultType].Value, Self.E]:
        """Sequence a borrowed error projection and retain the original error on success.

        The projection runs only on Err and must return Result[U, E]. Its Ok payload is discarded and the original error is retained; its Err replaces that error. Ok passes through unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Sequence a borrowed error projection and retain the original error on success.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return self^.or_else(_ResultRetain[Self.T, Self.E, C, False, False, True](function^))

    def flat_tap_err[U: Movable & Deinitable, o: ImmOrigin, //, C: def(Self.E) -> Result[U, Self.E]](deinit self, ref[o] function: C) raises Never -> Result[Self.T, Self.E]:
        """Sequence a borrowed error projection and retain the original error on success."""
        def invoke_0(function: C, payload: Self.E) raises Never capturing -> Result[U, Self.E]:
            return function(payload)
        return self^.flat_tap_err(_NativeBorrowRef[Self.E, Result[U, Self.E], Never, C, False, o, True, invoke_0](Pointer(to=function)))

    def flat_tap_err[U: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: def(Self.E) raises X -> Result[U, Self.E]](deinit self, ref[o] function: C) raises X -> Result[Self.T, Self.E]:
        """Sequence a borrowed error projection and retain the original error on success."""
        def invoke_0(function: C, payload: Self.E) raises X capturing -> Result[U, Self.E]:
            return function(payload)
        return self^.flat_tap_err(_NativeBorrowRef[Self.E, Result[U, Self.E], X, C, True, o, True, invoke_0](Pointer(to=function)))

    def attempt_tap[C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Result[Self.T, Self.E] where C.Payload == Result[Self.T, Self.E] and C.Result == Result[downcast[C.Result, _ResultType].Value, Self.E]:
        """Sequence an observer of the whole Result and retain its outcome on observer success.

        The observer borrows the entire Result, runs once on either branch and returns Result[U, E]. Its Ok payload is discarded and the original Result is retained; its Err replaces the original outcome. Native raised errors remain raised. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Sequence an observer of the whole Result and retain its outcome on observer success.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return _ResultRetain[Self.T, Self.E, C, False, True](function^).call_once(self^)

    def attempt_tap[U: Movable & Deinitable, o: ImmOrigin, //, C: def(Result[Self.T, Self.E]) -> Result[U, Self.E]](deinit self, ref[o] function: C) raises Never -> Result[Self.T, Self.E]:
        """Sequence an observer of the whole Result and retain its outcome on observer success."""
        def invoke_0(function: C, payload: Result[Self.T, Self.E]) raises Never capturing -> Result[U, Self.E]:
            return function(payload)
        return self^.attempt_tap(_NativeBorrowRef[Result[Self.T, Self.E], Result[U, Self.E], Never, C, False, o, True, invoke_0](Pointer(to=function)))

    def attempt_tap[U: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: def(Result[Self.T, Self.E]) raises X -> Result[U, Self.E]](deinit self, ref[o] function: C) raises X -> Result[Self.T, Self.E]:
        """Sequence an observer of the whole Result and retain its outcome on observer success."""
        def invoke_0(function: C, payload: Result[Self.T, Self.E]) raises X capturing -> Result[U, Self.E]:
            return function(payload)
        return self^.attempt_tap(_NativeBorrowRef[Result[Self.T, Self.E], Result[U, Self.E], X, C, True, o, True, invoke_0](Pointer(to=function)))

    def map_both[C: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var on_ok: C, var on_err: G) raises _CommonError[C.Error, G.Error] -> Result[C.Out, G.Out] where C.Arg == Self.T and G.Arg == Self.E and (C.Error == Never or G.Error == Never or C.Error == G.Error):
        """Transform either payload, preserving its Result constructor.

        The selected handler consumes its payload. The success and stored error types may both change. Execution is immediate. Native handlers are borrowed in place; library handlers are consumed and use their declared receiver mode, including disposal of the skipped handler. Payloads, captures and native raised errors keep their ownership and origins. No Copyable requirement is added.

        Parameters:
            C: The success handler type.
            G: The error handler type.

        Args:
            on_ok: The handler consuming the success payload.
            on_err: The handler consuming the error payload.

        Returns:
            Transform either payload, preserving its Result constructor.

        Raises:
            The selected handler native error, unchanged. Both must share an error type, or one must be non-raising.
        """
        return _result_both[Self.T, Self.E, C.Out, G.Out, C.Out, G.Out, C.Error, G.Error, _CommonError[C.Error, G.Error], C, G, True, False, _call_transform[Self.T, C], _call_transform[Self.E, G]](self^, on_ok^, on_err^)

    def map_both[C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: def(var Self.E) -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises C.Error -> Result[C.Out, S] where C.Arg == Self.T:
        """Transform either payload, preserving its Result constructor."""
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, C.Out, S, C.Out, S, C.Error, Never, C.Error, C, Pointer[G, q], True, False, _call_transform[Self.T, C], invoke_on_err](self^, on_ok^, Pointer(to=on_err))

    def map_both[C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: def(var Self.E) raises Y -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises _CommonError[C.Error, Y] -> Result[C.Out, S] where C.Arg == Self.T and (C.Error == Never or Y == Never or C.Error == Y):
        """Transform either payload, preserving its Result constructor."""
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, C.Out, S, C.Out, S, C.Error, Y, _CommonError[C.Error, Y], C, Pointer[G, q], True, False, _call_transform[Self.T, C], invoke_on_err](self^, on_ok^, Pointer(to=on_err))

    def map_both[R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, C: def(var Self.T) -> R](deinit self, ref[o] on_ok: C, var on_err: G) raises G.Error -> Result[R, G.Out] where G.Arg == Self.E:
        """Transform either payload, preserving its Result constructor."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises Never capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        return _result_both[Self.T, Self.E, R, G.Out, R, G.Out, Never, G.Error, G.Error, Pointer[C, o], G, True, False, invoke_on_ok, _call_transform[Self.E, G]](self^, Pointer(to=on_ok), on_err^)

    def map_both[R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, C: def(var Self.T) -> R, G: def(var Self.E) -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Never -> Result[R, S]:
        """Transform either payload, preserving its Result constructor."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises Never capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, R, S, R, S, Never, Never, Never, Pointer[C, o], Pointer[G, q], True, False, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err))

    def map_both[R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, C: def(var Self.T) -> R, Y: Movable & Deinitable, G: def(var Self.E) raises Y -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Y -> Result[R, S]:
        """Transform either payload, preserving its Result constructor."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises Never capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, R, S, R, S, Never, Y, Y, Pointer[C, o], Pointer[G, q], True, False, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err))

    def map_both[R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: def(var Self.T) raises X -> R](deinit self, ref[o] on_ok: C, var on_err: G) raises _CommonError[X, G.Error] -> Result[R, G.Out] where G.Arg == Self.E and (X == Never or G.Error == Never or X == G.Error):
        """Transform either payload, preserving its Result constructor."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises X capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        return _result_both[Self.T, Self.E, R, G.Out, R, G.Out, X, G.Error, _CommonError[X, G.Error], Pointer[C, o], G, True, False, invoke_on_ok, _call_transform[Self.E, G]](self^, Pointer(to=on_ok), on_err^)

    def map_both[R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var Self.T) raises X -> R, G: def(var Self.E) -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises X -> Result[R, S]:
        """Transform either payload, preserving its Result constructor."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises X capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, R, S, R, S, X, Never, X, Pointer[C, o], Pointer[G, q], True, False, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err))

    def map_both[R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var Self.T) raises X -> R, Y: Movable & Deinitable, G: def(var Self.E) raises Y -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _CommonError[X, Y] -> Result[R, S] where (X == Never or Y == Never or X == Y):
        """Transform either payload, preserving its Result constructor."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises X capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, R, S, R, S, X, Y, _CommonError[X, Y], Pointer[C, o], Pointer[G, q], True, False, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err))

    def redeem[C: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var on_ok: C, var on_err: G) raises _CommonError[C.Error, G.Error] -> Result[C.Out, Self.E] where C.Arg == Self.T and G.Arg == Self.E and C.Out == G.Out and (C.Error == Never or G.Error == Never or C.Error == G.Error):
        """Turn either branch into a success with a common value type.

        Both handlers return the same value type. The selected result is wrapped in Ok, retaining the original stored error type. Execution is immediate. Native handlers are borrowed in place; library handlers are consumed and use their declared receiver mode, including disposal of the skipped handler. Payloads, captures and native raised errors keep their ownership and origins. No Copyable requirement is added.

        Parameters:
            C: The success handler type.
            G: The error handler type.

        Args:
            on_ok: The handler consuming the success payload.
            on_err: The handler consuming the error payload.

        Returns:
            Turn either branch into a success with a common value type.

        Raises:
            The selected handler native error, unchanged. Both must share an error type, or one must be non-raising.
        """
        return _result_both[Self.T, Self.E, C.Out, Self.E, C.Out, G.Out, C.Error, G.Error, _CommonError[C.Error, G.Error], C, G, True, True, _call_transform[Self.T, C], _call_transform[Self.E, G]](self^, on_ok^, on_err^)

    def redeem[C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: def(var Self.E) -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises C.Error -> Result[C.Out, Self.E] where C.Arg == Self.T and C.Out == S:
        """Turn either branch into a success with a common value type."""
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, C.Out, Self.E, C.Out, S, C.Error, Never, C.Error, C, Pointer[G, q], True, True, _call_transform[Self.T, C], invoke_on_err](self^, on_ok^, Pointer(to=on_err))

    def redeem[C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: def(var Self.E) raises Y -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises _CommonError[C.Error, Y] -> Result[C.Out, Self.E] where C.Arg == Self.T and C.Out == S and (C.Error == Never or Y == Never or C.Error == Y):
        """Turn either branch into a success with a common value type."""
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, C.Out, Self.E, C.Out, S, C.Error, Y, _CommonError[C.Error, Y], C, Pointer[G, q], True, True, _call_transform[Self.T, C], invoke_on_err](self^, on_ok^, Pointer(to=on_err))

    def redeem[R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, C: def(var Self.T) -> R](deinit self, ref[o] on_ok: C, var on_err: G) raises G.Error -> Result[R, Self.E] where G.Arg == Self.E and R == G.Out:
        """Turn either branch into a success with a common value type."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises Never capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        return _result_both[Self.T, Self.E, R, Self.E, R, G.Out, Never, G.Error, G.Error, Pointer[C, o], G, True, True, invoke_on_ok, _call_transform[Self.E, G]](self^, Pointer(to=on_ok), on_err^)

    def redeem[R: Movable & Deinitable, o: ImmOrigin, q: ImmOrigin, //, C: def(var Self.T) -> R, G: def(var Self.E) -> R](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Never -> Result[R, Self.E]:
        """Turn either branch into a success with a common value type."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises Never capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Never capturing -> R:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, R, Self.E, R, R, Never, Never, Never, Pointer[C, o], Pointer[G, q], True, True, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err))

    def redeem[R: Movable & Deinitable, o: ImmOrigin, q: ImmOrigin, //, C: def(var Self.T) -> R, Y: Movable & Deinitable, G: def(var Self.E) raises Y -> R](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Y -> Result[R, Self.E]:
        """Turn either branch into a success with a common value type."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises Never capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Y capturing -> R:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, R, Self.E, R, R, Never, Y, Y, Pointer[C, o], Pointer[G, q], True, True, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err))

    def redeem[R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: def(var Self.T) raises X -> R](deinit self, ref[o] on_ok: C, var on_err: G) raises _CommonError[X, G.Error] -> Result[R, Self.E] where G.Arg == Self.E and R == G.Out and (X == Never or G.Error == Never or X == G.Error):
        """Turn either branch into a success with a common value type."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises X capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        return _result_both[Self.T, Self.E, R, Self.E, R, G.Out, X, G.Error, _CommonError[X, G.Error], Pointer[C, o], G, True, True, invoke_on_ok, _call_transform[Self.E, G]](self^, Pointer(to=on_ok), on_err^)

    def redeem[R: Movable & Deinitable, o: ImmOrigin, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var Self.T) raises X -> R, G: def(var Self.E) -> R](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises X -> Result[R, Self.E]:
        """Turn either branch into a success with a common value type."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises X capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Never capturing -> R:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, R, Self.E, R, R, X, Never, X, Pointer[C, o], Pointer[G, q], True, True, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err))

    def redeem[R: Movable & Deinitable, o: ImmOrigin, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var Self.T) raises X -> R, Y: Movable & Deinitable, G: def(var Self.E) raises Y -> R](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _CommonError[X, Y] -> Result[R, Self.E] where (X == Never or Y == Never or X == Y):
        """Turn either branch into a success with a common value type."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises X capturing -> R:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Y capturing -> R:
            return context[](rebind_var[Self.E](payload^))
        return _result_both[Self.T, Self.E, R, Self.E, R, R, X, Y, _CommonError[X, Y], Pointer[C, o], Pointer[G, q], True, True, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err))

    def redeem_with[C: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var on_ok: C, var on_err: G) raises _CommonError[C.Error, G.Error] -> C.Out where C.Arg == Self.T and G.Arg == Self.E and C.Out == G.Out and (C.Error == Never or G.Error == Never or C.Error == G.Error):
        """Continue either branch with the selected handler Result.

        Both handlers return the same Result type, which may change both success and stored error types. Only the original branch selects a handler; a returned Err never invokes the other handler. Execution is immediate. Native handlers are borrowed in place; library handlers are consumed and use their declared receiver mode, including disposal of the skipped handler. Payloads, captures and native raised errors keep their ownership and origins. No Copyable requirement is added.

        Parameters:
            C: The success handler type.
            G: The error handler type.

        Args:
            on_ok: The handler consuming the success payload.
            on_err: The handler consuming the error payload.

        Returns:
            Continue either branch with the selected handler Result.

        Raises:
            The selected handler native error, unchanged. Both must share an error type, or one must be non-raising.
        """
        return rebind_var[C.Out](_result_both[Self.T, Self.E, downcast[C.Out, _ResultType].Value, downcast[C.Out, _ResultType].Error, C.Out, G.Out, C.Error, G.Error, _CommonError[C.Error, G.Error], C, G, False, True, _call_transform[Self.T, C], _call_transform[Self.E, G]](self^, on_ok^, on_err^))

    def redeem_with[C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: def(var Self.E) -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises C.Error -> C.Out where C.Arg == Self.T and C.Out == S:
        """Continue either branch with the selected handler Result."""
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Never capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return rebind_var[C.Out](_result_both[Self.T, Self.E, downcast[C.Out, _ResultType].Value, downcast[C.Out, _ResultType].Error, C.Out, S, C.Error, Never, C.Error, C, Pointer[G, q], False, True, _call_transform[Self.T, C], invoke_on_err](self^, on_ok^, Pointer(to=on_err)))

    def redeem_with[C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: def(var Self.E) raises Y -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises _CommonError[C.Error, Y] -> C.Out where C.Arg == Self.T and C.Out == S and (C.Error == Never or Y == Never or C.Error == Y):
        """Continue either branch with the selected handler Result."""
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Y capturing -> S:
            return context[](rebind_var[Self.E](payload^))
        return rebind_var[C.Out](_result_both[Self.T, Self.E, downcast[C.Out, _ResultType].Value, downcast[C.Out, _ResultType].Error, C.Out, S, C.Error, Y, _CommonError[C.Error, Y], C, Pointer[G, q], False, True, _call_transform[Self.T, C], invoke_on_err](self^, on_ok^, Pointer(to=on_err)))

    def redeem_with[o: ImmOrigin, U: Movable & Deinitable, V: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //, C: def(var Self.T) -> Result[U, V]](deinit self, ref[o] on_ok: C, var on_err: G) raises G.Error -> Result[U, V] where G.Arg == Self.E and Result[U, V] == G.Out:
        """Continue either branch with the selected handler Result."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises Never capturing -> Result[U, V]:
            return context[](rebind_var[Self.T](payload^))
        return rebind_var[Result[U, V]](_result_both[Self.T, Self.E, downcast[Result[U, V], _ResultType].Value, downcast[Result[U, V], _ResultType].Error, Result[U, V], G.Out, Never, G.Error, G.Error, Pointer[C, o], G, False, True, invoke_on_ok, _call_transform[Self.E, G]](self^, Pointer(to=on_ok), on_err^))

    def redeem_with[o: ImmOrigin, U: Movable & Deinitable, V: Movable & Deinitable, q: ImmOrigin, //, C: def(var Self.T) -> Result[U, V], G: def(var Self.E) -> Result[U, V]](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Never -> Result[U, V]:
        """Continue either branch with the selected handler Result."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises Never capturing -> Result[U, V]:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Never capturing -> Result[U, V]:
            return context[](rebind_var[Self.E](payload^))
        return rebind_var[Result[U, V]](_result_both[Self.T, Self.E, downcast[Result[U, V], _ResultType].Value, downcast[Result[U, V], _ResultType].Error, Result[U, V], Result[U, V], Never, Never, Never, Pointer[C, o], Pointer[G, q], False, True, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err)))

    def redeem_with[o: ImmOrigin, U: Movable & Deinitable, V: Movable & Deinitable, q: ImmOrigin, //, C: def(var Self.T) -> Result[U, V], Y: Movable & Deinitable, G: def(var Self.E) raises Y -> Result[U, V]](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Y -> Result[U, V]:
        """Continue either branch with the selected handler Result."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises Never capturing -> Result[U, V]:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Y capturing -> Result[U, V]:
            return context[](rebind_var[Self.E](payload^))
        return rebind_var[Result[U, V]](_result_both[Self.T, Self.E, downcast[Result[U, V], _ResultType].Value, downcast[Result[U, V], _ResultType].Error, Result[U, V], Result[U, V], Never, Y, Y, Pointer[C, o], Pointer[G, q], False, True, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err)))

    def redeem_with[o: ImmOrigin, U: Movable & Deinitable, V: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: def(var Self.T) raises X -> Result[U, V]](deinit self, ref[o] on_ok: C, var on_err: G) raises _CommonError[X, G.Error] -> Result[U, V] where G.Arg == Self.E and Result[U, V] == G.Out and (X == Never or G.Error == Never or X == G.Error):
        """Continue either branch with the selected handler Result."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises X capturing -> Result[U, V]:
            return context[](rebind_var[Self.T](payload^))
        return rebind_var[Result[U, V]](_result_both[Self.T, Self.E, downcast[Result[U, V], _ResultType].Value, downcast[Result[U, V], _ResultType].Error, Result[U, V], G.Out, X, G.Error, _CommonError[X, G.Error], Pointer[C, o], G, False, True, invoke_on_ok, _call_transform[Self.E, G]](self^, Pointer(to=on_ok), on_err^))

    def redeem_with[o: ImmOrigin, U: Movable & Deinitable, V: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var Self.T) raises X -> Result[U, V], G: def(var Self.E) -> Result[U, V]](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises X -> Result[U, V]:
        """Continue either branch with the selected handler Result."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises X capturing -> Result[U, V]:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Never capturing -> Result[U, V]:
            return context[](rebind_var[Self.E](payload^))
        return rebind_var[Result[U, V]](_result_both[Self.T, Self.E, downcast[Result[U, V], _ResultType].Value, downcast[Result[U, V], _ResultType].Error, Result[U, V], Result[U, V], X, Never, X, Pointer[C, o], Pointer[G, q], False, True, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err)))

    def redeem_with[o: ImmOrigin, U: Movable & Deinitable, V: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var Self.T) raises X -> Result[U, V], Y: Movable & Deinitable, G: def(var Self.E) raises Y -> Result[U, V]](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _CommonError[X, Y] -> Result[U, V] where (X == Never or Y == Never or X == Y):
        """Continue either branch with the selected handler Result."""
        def invoke_on_ok(var payload: Self.T, var context: Pointer[C, o]) raises X capturing -> Result[U, V]:
            return context[](rebind_var[Self.T](payload^))
        def invoke_on_err(var payload: Self.E, var context: Pointer[G, q]) raises Y capturing -> Result[U, V]:
            return context[](rebind_var[Self.E](payload^))
        return rebind_var[Result[U, V]](_result_both[Self.T, Self.E, downcast[Result[U, V], _ResultType].Value, downcast[Result[U, V], _ResultType].Error, Result[U, V], Result[U, V], X, Y, _CommonError[X, Y], Pointer[C, o], Pointer[G, q], False, True, invoke_on_ok, invoke_on_err](self^, Pointer(to=on_ok), Pointer(to=on_err)))

    # --- end Result combinators ---


def attempt[T: Movable & Deinitable, //, F: def() -> T](function: F) -> Result[T, Never]:
    """Call `function` once and capture its outcome: `Ok(result)`, or `Err(error)` for its declared error.

    Overloads take zero, one or two positional arguments with their native read,
    `var` or `mut` conventions, and a native keyword pack `var **kwargs: K` after
    them (homogeneous values, or a `StringDict[K]` expanded with
    `**options^`). Pass consumed arguments with `^`. Changes made through a `mut`
    argument before a failure remain visible. Every declared positional
    parameter must be supplied, including defaulted ones; other call shapes
    are written as a closure passed to the zero-argument form.

    The function is borrowed and reusable. A returned `Result` is ordinary
    success data, and a declared `StopIteration` is captured like any other
    error; process aborts are never caught.

    Parameters:
        T: The result type.
        F: The function's type: a plain function or a closure.

    Args:
        function: The function, borrowed; it runs once.

    Returns:
        `Ok(result)`; a pure function never produces `Err`, so the error type
        is `Never`.
    """
    return _attempt_core[T, Never, F, _attempt_native_pure[T, F]](function)


def attempt[T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def() raises E -> T](function: F) -> Result[T, E]:
    """Call once and retain the exact native error as an Err payload."""
    return _attempt_core[T, E, F, _attempt_native[T, E, F]](function)


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A) -> T](
    function: F, first: A
) -> Result[T, Never] where not conforms_to(A, TrivialRegisterPassable):
    """Capture a pure call once; its error channel is Never."""
    return Result[T, Never](Ok(function(first)))


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A) raises E -> T](
    function: F, first: A
) -> Result[T, E] where not conforms_to(A, TrivialRegisterPassable):
    """Invoke once with native argument conventions and retain the exact typed error."""
    try: return Result[T, E](Ok(function(first)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A) -> T](
    function: F, var first: A
) -> Result[T, Never]:
    """Capture a pure call once; its error channel is Never."""
    return Result[T, Never](Ok(function(first^)))


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A) raises E -> T](
    function: F, var first: A
) -> Result[T, E]:
    """Invoke once with native argument conventions and retain the exact typed error."""
    try: return Result[T, E](Ok(function(first^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, B) -> T](
    function: F, first: A, second: B
) -> Result[T, Never] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    """Capture a pure call once; its error channel is Never."""
    return Result[T, Never](Ok(function(first, second)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, B) raises E -> T](
    function: F, first: A, second: B
) -> Result[T, E] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    """Invoke once with native argument conventions and retain the exact typed error."""
    try: return Result[T, E](Ok(function(first, second)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, B) -> T](
    function: F, var first: A, second: B
) -> Result[T, Never] where not conforms_to(B, TrivialRegisterPassable):
    """Capture a pure call once; its error channel is Never."""
    return Result[T, Never](Ok(function(first^, second)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, B) raises E -> T](
    function: F, var first: A, second: B
) -> Result[T, E] where not conforms_to(B, TrivialRegisterPassable):
    """Invoke once with native argument conventions and retain the exact typed error."""
    try: return Result[T, E](Ok(function(first^, second)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, var B) -> T](
    function: F, first: A, var second: B
) -> Result[T, Never] where not conforms_to(A, TrivialRegisterPassable):
    """Capture a pure call once; its error channel is Never."""
    return Result[T, Never](Ok(function(first, second^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, var B) raises E -> T](
    function: F, first: A, var second: B
) -> Result[T, E] where not conforms_to(A, TrivialRegisterPassable):
    """Invoke once with native argument conventions and retain the exact typed error."""
    try: return Result[T, E](Ok(function(first, second^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, var B) -> T](
    function: F, var first: A, var second: B
) -> Result[T, Never]:
    """Capture a pure call once; its error channel is Never."""
    return Result[T, Never](Ok(function(first^, second^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, var B) raises E -> T](
    function: F, var first: A, var second: B
) -> Result[T, E]:
    """Invoke once with native argument conventions and retain the exact typed error."""
    try: return Result[T, E](Ok(function(first^, second^)))
    except error: return Result[T, E](Err(error^))


# Native keyword packs are owned homogeneous dictionaries. Fixed prefixes keep
# their native argument conventions; all bridge arguments are positional-only.
def attempt[K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var **kwargs: K) -> T](
    function: F, /, var **values: K
) -> Result[T, Never]:
    """Forward native keyword values once; preserve the selected native error channel."""
    return Result[T, Never](Ok(function(**values^)))


def attempt[K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var **kwargs: K) raises E -> T](
    function: F, /, var **values: K
) -> Result[T, E]:
    """Forward native keyword values once; preserve the selected native error channel."""
    try: return Result[T, E](Ok(function(**values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, /, var **kwargs: K) -> T](
    function: F, first: A, /, var **values: K
) -> Result[T, Never] where not conforms_to(A, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    return Result[T, Never](Ok(function(first, **values^)))


def attempt[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, /, var **kwargs: K) raises E -> T](
    function: F, first: A, /, var **values: K
) -> Result[T, E] where not conforms_to(A, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    try: return Result[T, E](Ok(function(first, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, /, var **kwargs: K) -> T](
    function: F, var first: A, /, var **values: K
) -> Result[T, Never]:
    """Forward native keyword values once; preserve the selected native error channel."""
    return Result[T, Never](Ok(function(first^, **values^)))


def attempt[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, /, var **kwargs: K) raises E -> T](
    function: F, var first: A, /, var **values: K
) -> Result[T, E]:
    """Forward native keyword values once; preserve the selected native error channel."""
    try: return Result[T, E](Ok(function(first^, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, B, /, var **kwargs: K) -> T](
    function: F, first: A, second: B, /, var **values: K
) -> Result[T, Never] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    return Result[T, Never](Ok(function(first, second, **values^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, B, /, var **kwargs: K) raises E -> T](
    function: F, first: A, second: B, /, var **values: K
) -> Result[T, E] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    try: return Result[T, E](Ok(function(first, second, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, B, /, var **kwargs: K) -> T](
    function: F, var first: A, second: B, /, var **values: K
) -> Result[T, Never] where not conforms_to(B, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    return Result[T, Never](Ok(function(first^, second, **values^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, B, /, var **kwargs: K) raises E -> T](
    function: F, var first: A, second: B, /, var **values: K
) -> Result[T, E] where not conforms_to(B, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    try: return Result[T, E](Ok(function(first^, second, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, var B, /, var **kwargs: K) -> T](
    function: F, first: A, var second: B, /, var **values: K
) -> Result[T, Never] where not conforms_to(A, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    return Result[T, Never](Ok(function(first, second^, **values^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, var B, /, var **kwargs: K) raises E -> T](
    function: F, first: A, var second: B, /, var **values: K
) -> Result[T, E] where not conforms_to(A, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    try: return Result[T, E](Ok(function(first, second^, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, var B, /, var **kwargs: K) -> T](
    function: F, var first: A, var second: B, /, var **values: K
) -> Result[T, Never]:
    """Forward native keyword values once; preserve the selected native error channel."""
    return Result[T, Never](Ok(function(first^, second^, **values^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, var B, /, var **kwargs: K) raises E -> T](
    function: F, var first: A, var second: B, /, var **values: K
) -> Result[T, E]:
    """Forward native keyword values once; preserve the selected native error channel."""
    try: return Result[T, E](Ok(function(first^, second^, **values^)))
    except error: return Result[T, E](Err(error^))


# Mutable prefixes retain exclusive native borrows on success and failure.
def attempt[A: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A) -> T](
    function: F, mut first: A
) -> Result[T, Never]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first)))


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A) raises E -> T](
    function: F, mut first: A
) -> Result[T, E]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, mut B) -> T](
    function: F, first: A, mut second: B
) -> Result[T, Never] where not conforms_to(A, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first, second)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, mut B) raises E -> T](
    function: F, first: A, mut second: B
) -> Result[T, E] where not conforms_to(A, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first, second)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, mut B) -> T](
    function: F, var first: A, mut second: B
) -> Result[T, Never]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first^, second)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, mut B) raises E -> T](
    function: F, var first: A, mut second: B
) -> Result[T, E]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first^, second)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, B) -> T](
    function: F, mut first: A, second: B
) -> Result[T, Never] where not conforms_to(B, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first, second)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, B) raises E -> T](
    function: F, mut first: A, second: B
) -> Result[T, E] where not conforms_to(B, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first, second)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, var B) -> T](
    function: F, mut first: A, var second: B
) -> Result[T, Never]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first, second^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, var B) raises E -> T](
    function: F, mut first: A, var second: B
) -> Result[T, E]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first, second^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, mut B) -> T](
    function: F, mut first: A, mut second: B
) -> Result[T, Never]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first, second)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, mut B) raises E -> T](
    function: F, mut first: A, mut second: B
) -> Result[T, E]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first, second)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, /, var **kwargs: K) -> T](
    function: F, mut first: A, /, var **values: K
) -> Result[T, Never]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first, **values^)))


def attempt[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, /, var **kwargs: K) raises E -> T](
    function: F, mut first: A, /, var **values: K
) -> Result[T, E]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, mut B, /, var **kwargs: K) -> T](
    function: F, first: A, mut second: B, /, var **values: K
) -> Result[T, Never] where not conforms_to(A, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first, second, **values^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, mut B, /, var **kwargs: K) raises E -> T](
    function: F, first: A, mut second: B, /, var **values: K
) -> Result[T, E] where not conforms_to(A, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first, second, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, mut B, /, var **kwargs: K) -> T](
    function: F, var first: A, mut second: B, /, var **values: K
) -> Result[T, Never]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first^, second, **values^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, mut B, /, var **kwargs: K) raises E -> T](
    function: F, var first: A, mut second: B, /, var **values: K
) -> Result[T, E]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first^, second, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, B, /, var **kwargs: K) -> T](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[T, Never] where not conforms_to(B, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first, second, **values^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, B, /, var **kwargs: K) raises E -> T](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[T, E] where not conforms_to(B, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first, second, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, var B, /, var **kwargs: K) -> T](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[T, Never]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first, second^, **values^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, var B, /, var **kwargs: K) raises E -> T](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[T, E]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first, second^, **values^)))
    except error: return Result[T, E](Err(error^))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, mut B, /, var **kwargs: K) -> T](
    function: F, mut first: A, mut second: B, /, var **values: K
) -> Result[T, Never]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    return Result[T, Never](Ok(function(first, second, **values^)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, mut B, /, var **kwargs: K) raises E -> T](
    function: F, mut first: A, mut second: B, /, var **values: K
) -> Result[T, E]:
    """Forward once, preserving caller mutation and the exact native error channel."""
    try: return Result[T, E](Ok(function(first, second, **values^)))
    except error: return Result[T, E](Err(error^))


def raise_on_err[T: Movable & Deinitable, E: Movable & Deinitable](
    var result: Result[T, E]
) raises E -> T:
    """Consume a Result and return its value, or raise its stored error.

    Parameters:
        T: The success type.
        E: The stored error type.

    Args:
        result: The Result, consumed.

    Returns:
        The success value.

    Raises:
        The stored error, with its original type.
    """
    return result^.raise_on_err()


def _keep_ok[T: Movable & Deinitable, E: Movable & Deinitable](var value: T) -> Result[T, E]:
    return Result[T, E](Ok(value^))


def _keep_err[T: Movable & Deinitable, E: Movable & Deinitable](var error: E) -> Result[T, E]:
    return Result[T, E](Err(error^))


@fieldwise_init
struct _ResultRetainFinish[T: Movable & Deinitable, E: Movable & Deinitable,
                          U: Movable & Deinitable, paired: Bool](Binary, Defaultable):
    comptime First = Self.T
    comptime Second = Result[Self.U, Self.E]
    comptime Keep = _Retained[Self.T, Self.U, Self.paired]
    comptime Out = Result[Self.Keep.Out, Self.E]
    def call(self, var value: Self.T, var produced: Self.Second) -> Self.Out:
        return produced^.map(Self.Keep(value^))


@fieldwise_init
struct _ResultRetain[T: Movable & Deinitable, E: Movable & Deinitable,
                     C: BorrowCallContract & Movable & Deinitable, paired: Bool, whole: Bool = False, failed: Bool = False](OnceUnary):
    """Sequence a borrowed projection, restoring the selected source constructor.

    Retention shares the bind/traversal adapter. Result's native transformation
    only unwraps the retained Result for whole-outcome observers.
    """
    var function: Self.C
    comptime Arg = Result[Self.T, Self.E] if Self.whole else Self.E if Self.failed else Self.T
    comptime U = downcast[Self.C.Result, _ResultType].Value
    comptime Value = Tuple[Self.T, Self.U] if Self.paired else Self.T
    comptime Out = Result[Self.Value, Self.E]
    comptime Error = Self.C.Failure
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert not Self.paired or not (Self.whole or Self.failed)
        comptime assert Self.C.Payload == Self.Arg, "Result retention: callback must borrow the selected payload"
        comptime assert Self.C.Result == Result[Self.U, Self.E], "Result retention: callback must return a Result with the same error type"
        comptime Retain = _Retain[Self.Arg, Self.C, _ResultRetainFinish[Self.Arg, Self.E, Self.U, Self.paired]]
        comptime assert _ErrorCompatible[Self.Error, Retain.Error]
        var retained = _unary_once_as[Self.Error](Retain(self.function^), arg^)
        comptime if Self.failed:
            return rebind_var[Self.Out](_result_transform[Self.E, Self.E, Self.T, Self.E, Identity[Self.E], True, True, False](
                Identity[Self.E](), rebind_var[Result[Self.E, Self.E]](retained^)))
        elif not Self.whole:
            comptime assert type_of(retained) == Self.Out
            return rebind_var[Self.Out](retained^)
        else:
            # A whole-outcome observer unwraps the retained Result.
            # Failed observer effects keep their Err.
            comptime assert type_of(retained) == Result[Self.Arg, Self.E]
            return _result_transform[Self.Arg, Self.E, Self.Value, Self.E, Identity[Self.Arg], True, False, True](
                Identity[Self.Arg](), rebind_var[Result[Self.Arg, Self.E]](retained^))


@fieldwise_init
struct _ResultConditional[C: BorrowCallContract & Movable & Deinitable, G: Movable & Deinitable](Movable):
    var predicate: Self.C
    var function: Self.G
    def apply[T: Movable & Deinitable, E: Movable & Deinitable,
              P: Movable & Deinitable, Q: Movable & Deinitable,
              Y: Movable & Deinitable, X: Movable & Deinitable,
              success: Bool, wrap: Bool, wrap_ok: Bool,
              continuation: def(var P, var Self.G) raises Y capturing -> Q](
        deinit self, var payload: P
    ) raises X capturing -> Result[T, E]:
        comptime assert P == (T if success else E)
        comptime assert Self.C.Payload == P and Self.C.Result == Bool, "Result predicate must borrow the selected payload and return Bool"
        comptime assert _ErrorCompatible[X, Self.C.Failure] and _ErrorCompatible[X, Y], "Result conditional: incompatible native errors"
        def keep(var value: P) raises X capturing -> Result[T, E]:
            return _transformed[T, E, P, success, True](value^)
        def apply(var value: P, var function: Self.G) raises X capturing -> Result[T, E]:
            try:
                return _transformed[T, E, Q, wrap_ok, wrap](continuation(value^, function^))
            except error:
                _propagate_error[X](error^)
        return _guard_owned[P, Self.C, Self.G, Result[T, E], X, not success, keep, apply](payload^, self.predicate^, self.function^)


def _conditional_result[T: Movable & Deinitable, E: Movable & Deinitable,
                        C: BorrowCallContract & Movable & Deinitable, G: Movable & Deinitable,
                        P: Movable & Deinitable, Q: Movable & Deinitable,
                        Y: Movable & Deinitable, X: Movable & Deinitable,
                        success: Bool, wrap: Bool, wrap_ok: Bool,
                        apply: def(var P, var G) raises Y capturing -> Q](
    var subject: Result[T, E], var predicate: C, var function: G
) raises X -> Result[T, E]:
    """Guard one owned payload, retaining it or applying a continuation.

    Ensure retains accepted successes; selective recovery retains rejected
    errors. Native continuations enter through the existing owned-context
    boundary: a capturing native signature cannot conform to Unary on Mojo 1.1.
    Library continuations use _call_transform and its canonical receiver dispatch.
    Constructor selection and Result validation stay in _transformed.
    """
    comptime Context = _ResultConditional[C, G]
    def invoke(var payload: P, var context: Context) raises X capturing -> Result[T, E]:
        return context^.apply[T, E, P, Q, Y, X, success, wrap, wrap_ok, apply](payload^)
    return _transform_result_owned[T, E, T, E, X, success, False, P, Result[T, E], Context, invoke](
        subject^, Context(predicate^, function^))


def attempt_once[F: OnceThunk](var function: F) -> Result[F.Out, F.Error]:
    """Consume a `OnceThunk`, call it once and capture its outcome.

    Receiver state, results and errors may be move-only; unused state is
    destroyed on every path. References in the result or error must belong to
    owners that outlive the thunk.

    Parameters:
        F: The thunk's type.

    Args:
        function: The thunk, consumed.

    Returns:
        `Ok(result)`, or `Err(error)` for its declared error.
    """
    var pending = Optional(function^)
    var context = Pointer(to=pending)
    return _attempt_core[F.Out, F.Error, type_of(context),
        _attempt_consuming[F, origin_of(pending)]](context)


# Native callbacks borrow the caller's context; library unary callbacks move
# into the transformation whole. Both enter the same owned transformation below.
def _transform_result[T: Movable & Deinitable, E: Movable & Deinitable,
                      U: Movable & Deinitable, V: Movable & Deinitable,
                      X: Movable & Deinitable, success: Bool, wrap: Bool,
                      P: Movable & Deinitable, Q: Movable & Deinitable, Context: AnyType,
                      apply: def(var P, Context) raises X capturing -> Q, wrap_ok: Bool = success](
    var subject: Result[T, E], context: Context
) raises X -> Result[U, V] where (E == V if success else T == U):
    return _transform_result_owned[T,E,U,V,X,success,wrap,P,Q,Pointer[Context,origin_of(context)],
        _borrowed_transform[P,Q,X,Context,origin_of(context),apply],wrap_ok](subject^,Pointer(to=context))


def _borrowed_transform[P:Movable & Deinitable,Q:Movable & Deinitable,X:Movable & Deinitable,
                        C:AnyType,origin:ImmOrigin,apply:def(var P,C) raises X capturing -> Q](
    var payload:P,var context:Pointer[C,origin]
) raises X capturing -> Q:
    return apply(payload^,context[])


def _transform_result_owned[T:Movable & Deinitable,E:Movable & Deinitable,U:Movable & Deinitable,V:Movable & Deinitable,
                            X:Movable & Deinitable,success:Bool,wrap:Bool,P:Movable & Deinitable,Q:Movable & Deinitable,
                            C:Movable & Deinitable,callback:def(var P,var C) raises X capturing -> Q,wrap_ok:Bool=success](
    var subject:Result[T,E],var context:C
) raises X -> Result[U,V] where (E == V if success else T == U):
    """Transform one case with `callback`; the other passes through.

    wrap_ok selects the constructor independently of the input case: recover
    transforms Err into Ok through this same branch and ownership mechanism.
    """
    comptime assert (T if success else E) == P, "Result: exact callback input required"
    comptime if success:
        return _fold_result_owned[T, E, Result[U, V], X, X, Never, C, NoneType,
            _transformed_call[P, Q, U, V, X, C, wrap_ok, wrap, callback, T],
            _preserved_result[E, U, V, False]](subject^, context^, NoneType())
    else:
        return _fold_result_owned[T, E, Result[U, V], X, Never, X, NoneType, C,
            _preserved_result[T, U, V, True],
            _transformed_call[P, Q, U, V, X, C, wrap_ok, wrap, callback, E]](subject^, NoneType(), context^)


def _fold_result_owned[T: Movable & Deinitable, E: Movable & Deinitable,
                       R: Movable & Deinitable, Z: Movable & Deinitable,
                       X: Movable & Deinitable, Y: Movable & Deinitable,
                       C: Movable & Deinitable, G: Movable & Deinitable,
                       apply_ok: def(var T, var C) raises X capturing -> R,
                       apply_err: def(var E, var G) raises Y capturing -> R](
    var subject: Result[T, E], var on_ok: C, var on_err: G
) raises Z -> R:
    """Select one owned payload and context; dispose of the inactive context.

    Owned folds and transformations share this branch boundary. Each native
    signature enters through a context adapter; no callback needs Copyable.
    """
    comptime assert _ErrorCompatible[Z, X] and _ErrorCompatible[Z, Y], "Result fold: incompatible native errors"
    if subject.is_ok():
        try:
            return apply_ok(subject^._take_ok(), on_ok^)
        except error:
            _propagate_error[Z](error^)
    try:
        return apply_err(subject^._take_err(), on_err^)
    except error:
        _propagate_error[Z](error^)


def _transformed_call[P: Movable & Deinitable, Q: Movable & Deinitable,
                      U: Movable & Deinitable, V: Movable & Deinitable,
                      X: Movable & Deinitable, C: Movable & Deinitable,
                      success: Bool, wrap: Bool,
                      apply: def(var P, var C) raises X capturing -> Q, A: Movable & Deinitable = P](
    var payload: A, var context: C
) raises X capturing -> Result[U, V]:
    comptime assert A == P, "Result: exact callback input required"
    return _transformed[U, V, Q, success, wrap](apply(rebind_var[P](payload^), context^))


def _preserved_result[P: Movable & Deinitable, U: Movable & Deinitable,
                      V: Movable & Deinitable, success: Bool](
    var payload: P, var unused: NoneType
) raises Never capturing -> Result[U, V]:
    return _transformed[U, V, P, success, True](payload^)


def _result_both[T: Movable & Deinitable, E: Movable & Deinitable,
                 U: Movable & Deinitable, V: Movable & Deinitable,
                 P: Movable & Deinitable, Q: Movable & Deinitable,
                 X: Movable & Deinitable, Y: Movable & Deinitable, Z: Movable & Deinitable,
                 C: Movable & Deinitable, G: Movable & Deinitable,
                 wrap: Bool, recover: Bool,
                 apply_ok: def(var T, var C) raises X capturing -> P,
                 apply_err: def(var E, var G) raises Y capturing -> Q](
    var subject: Result[T, E], var on_ok: C, var on_err: G
) raises Z -> Result[U, V]:
    """Map, recover or sequence either branch through the owned fold."""
    return _fold_result_owned[T, E, Result[U, V], Z, X, Y, C, G,
        _transformed_call[T, P, U, V, X, C, True, wrap, apply_ok],
        _transformed_call[E, Q, U, V, Y, G, recover, wrap, apply_err]](subject^, on_ok^, on_err^)


def _transformed[U:Movable & Deinitable,V:Movable & Deinitable,Q:Movable & Deinitable,success:Bool,wrap:Bool](
    var output:Q
) -> Result[U,V]:
    """A callback's output as the transformed Result: wrapped in the case, or a Result itself."""
    comptime if not wrap:
        comptime assert Q == Result[U,V], "Result: exact sequenced Result required"
        return rebind_var[Result[U,V]](output^)
    elif success:
        comptime assert Q == U, "Result: exact mapped success required"
        return _keep_ok[U,V](rebind_var[U](output^))
    else:
        comptime assert Q == V, "Result: exact mapped error required"
        return _keep_err[U,V](rebind_var[V](output^))


def _attempt_core[R: Movable & Deinitable, E: Movable & Deinitable, C: AnyType,
                  apply: def(C) raises E capturing -> R](context: C) -> Result[R,E]:
    try:
        return Result[R,E](Ok(apply(context)))
    except error:
        return Result[R,E](Err(error^))


def _attempt_consuming[F: OnceThunk, origin: MutOrigin](
    context: Pointer[Optional[F], origin]
) raises F.Error capturing -> F.Out:
    # _attempt_core borrows its native context; this boundary moves the pending
    # owner into call_once. Result/error conversion stays shared.
    var function = context[].take()
    return function^.call_once()


def _attempt_native[R: Movable & Deinitable, E: Movable & Deinitable,
                    F: def() raises E -> R](function: F) raises E capturing -> R:
    return function()


# Pure and raising native traits cannot be substituted through an enclosing
# generic function on Mojo 1.1. Both ABI adapters use the same Result bridge.
def _attempt_native_pure[R: Movable & Deinitable, F: def() -> R](
    function: F
) raises Never capturing -> R:
    return function()




def _call_transform[P:Movable & Deinitable,F:UnaryContract & Movable & Deinitable,
                    Q:Movable & Deinitable = F.Out](
    var payload:P,var function:F
) raises F.Error capturing -> Q:
    comptime assert F.Arg == P and F.Out == Q
    return rebind_var[Q](call_once(function^,rebind_var[F.Arg](payload^)))


def _result_transform[T:Movable & Deinitable,E:Movable & Deinitable,
                      U:Movable & Deinitable,V:Movable & Deinitable,
                      F:UnaryContract & Movable & Deinitable,success:Bool,wrap:Bool,wrap_ok:Bool=success](
    var function:F,var value:Result[T,E]
) raises F.Error -> Result[U,V] where (E == V if success else T == U):
    comptime P = T if success else E
    return _transform_result_owned[T,E,U,V,F.Error,success,wrap,P,F.Out,F,
        _call_transform[P,F],wrap_ok](value^,function^)
