"""Typed result values stored in place: a native Variant of `Ok` and `Err`."""
from fp.callables.protocols import Unary, OnceUnary, OnceThunk, UnaryContract, BorrowCallable, BorrowOnceCallable
from fp.callables.invoke import call_once, invoke_borrowed, invoke_borrowed_once
from fp.adt.data import Cases, Data, Value, _ChoiceType
from std.builtin.rebind import rebind_var, downcast
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error


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
        if self.is_ok():
            return on_ok(self^._take_ok())
        return on_err(self^._take_err())

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
        if self.is_ok():
            return on_ok(self^._take_ok())
        return on_err(self^._take_err())

    def fold_owned[R: Movable & Deinitable, X: Movable & Deinitable, //,
             F: def(var Self.T) -> R,
             G: def(var Self.E) raises X -> R](
        deinit self, on_ok: F, on_err: G
    ) raises X -> R:
        """Consuming fold with a raising error callback."""
        if self.is_ok():
            return on_ok(self^._take_ok())
        return on_err(self^._take_err())

    def fold_owned[R: Movable & Deinitable, X: Movable & Deinitable, Y: Movable & Deinitable, //,
             F: def(var Self.T) raises X -> R,
             G: def(var Self.E) raises Y -> R](
        deinit self, on_ok: F, on_err: G
    ) raises _ResultFailure[X, Y] -> R where X == Never or Y == Never or X == Y:
        """Consuming fold with two raising callbacks, which raise one error type."""
        comptime assert _ErrorCompatible[_ResultFailure[X, Y], X] and _ErrorCompatible[_ResultFailure[X, Y], Y]
        if self.is_ok():
            try:
                return on_ok(self^._take_ok())
            except error:
                _propagate_error[_ResultFailure[X, Y]](error^)
        try:
            return on_err(self^._take_err())
        except error:
            _propagate_error[_ResultFailure[X, Y]](error^)

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
        comptime Z = _ResultFailure[F.Error, G.Error]
        comptime assert _ErrorCompatible[Z, F.Error] and _ErrorCompatible[Z, G.Error]
        if self.is_ok():
            try:
                return on_ok.call(rebind_var[F.Arg](self^._take_ok()))
            except error:
                _propagate_error[Z](error^)
        try:
            return rebind_var[F.Out](on_err.call(rebind_var[G.Arg](self^._take_err())))
        except error:
            _propagate_error[Z](error^)

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
        comptime Z = _ResultFailure[F.Error, G.Error]
        comptime assert _ErrorCompatible[Z, F.Error] and _ErrorCompatible[Z, G.Error]
        if self.is_ok():
            try:
                return on_ok^.call_once(rebind_var[F.Arg](self^._take_ok()))
            except error:
                _propagate_error[Z](error^)
        try:
            return rebind_var[F.Out](on_err^.call_once(rebind_var[G.Arg](self^._take_err())))
        except error:
            _propagate_error[Z](error^)

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
                      apply: def(var P, Context) raises X capturing -> Q](
    var subject: Result[T, E], context: Context
) raises X -> Result[U, V] where (E == V if success else T == U):
    return _transform_result_owned[T,E,U,V,X,success,wrap,P,Q,Pointer[Context,origin_of(context)],
        _borrowed_transform[P,Q,X,Context,origin_of(context),apply]](subject^,Pointer(to=context))


def _borrowed_transform[P:Movable & Deinitable,Q:Movable & Deinitable,X:Movable & Deinitable,
                        C:AnyType,origin:ImmOrigin,apply:def(var P,C) raises X capturing -> Q](
    var payload:P,var context:Pointer[C,origin]
) raises X capturing -> Q:
    return apply(payload^,context[])


def _transform_result_owned[T:Movable & Deinitable,E:Movable & Deinitable,U:Movable & Deinitable,V:Movable & Deinitable,
                            X:Movable & Deinitable,success:Bool,wrap:Bool,P:Movable & Deinitable,Q:Movable & Deinitable,
                            C:Movable & Deinitable,callback:def(var P,var C) raises X capturing -> Q](
    var subject:Result[T,E],var context:C
) raises X -> Result[U,V] where (E == V if success else T == U):
    """Transform one case with `callback` (wrapped, or a Result itself); the other passes through."""
    comptime assert (T if success else E) == P, "Result: exact callback input required"
    if subject.is_ok():
        var value = subject^._take_ok()
        comptime if success:
            return _transformed[U,V,Q,success,wrap](callback(rebind_var[P](value^), context^))
        else:
            return _keep_ok[U,V](rebind_var[U](value^))
    var error = subject^._take_err()
    comptime if success:
        return _keep_err[U,V](rebind_var[V](error^))
    else:
        return _transformed[U,V,Q,success,wrap](callback(rebind_var[P](error^), context^))


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




def _call_transform[P:Movable & Deinitable,F:UnaryContract & Movable & Deinitable](
    var payload:P,var function:F
) raises F.Error capturing -> F.Out:
    comptime assert F.Arg == P
    return call_once(function^,rebind_var[F.Arg](payload^))


def _result_transform[T:Movable & Deinitable,E:Movable & Deinitable,
                      U:Movable & Deinitable,V:Movable & Deinitable,
                      F:UnaryContract & Movable & Deinitable,success:Bool,wrap:Bool](
    var function:F,var value:Result[T,E]
) raises F.Error -> Result[U,V] where (E == V if success else T == U):
    comptime P = T if success else E
    return _transform_result_owned[T,E,U,V,F.Error,success,wrap,P,F.Out,F,
        _call_transform[P,F]](value^,function^)
