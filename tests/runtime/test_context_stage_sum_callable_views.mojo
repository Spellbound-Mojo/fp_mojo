"""Borrow chains across numeric effects and whole-value family transitions."""
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, ResultFamily, IdentityFamily, ListFamily
from fp.data import Result, Ok, Err
from fp.callables import Unary
from fp.callables._views import _UnaryViewable
from fp.callables._receiver import _SharedUnaryRef
from algebra_support.box import Box, BoxMonad
from fp.effects import Reader, run
from std.testing import assert_equal, assert_true

def optional(value: Int) -> Optional[Int]: return Optional(value)
def result(value: Int) -> Result[Float64, String]: return Ok(Float64(value))
def later(value: Int) -> Reader[Int].Pure[Float64]: return Reader[Int].pure(Float64(value))
def collect(value: Int) -> List[Int]: return [value, value + 1]
def size(var values: List[Int]) -> Int: return len(values)
def twice(value: Int) -> Int: return value * 2

def check_basics() raises:
    var ordinary = kleisli[OptionalFamily](optional)
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect(ordinary).get().value(), 3)
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect[OptionalFamily](ordinary).get().value(), 3)
    assert_equal(pipeline(List[Int]()).sum_by_effect(ordinary).get().value(), 0)
    assert_equal(ordinary.call(4).value(), 4)
    var checked = kleisli[ResultFamily[String]](result)
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect(checked).raise_on_err(), 3.0)
    var deferred = kleisli[Reader[Int]](later)
    var pending = pipeline(List[Int]([1, 2])).sum_by_effect(deferred).get()
    assert_equal(run[Reader[Int]](pending^, 0), 3.0)
    var chain = kleisli[IdentityFamily](collect)
    assert_equal(pipeline(3).then(chain).map(size).get(), 2)
    assert_equal(pipeline(3).then[ListFamily](chain).map(twice).get(), [6, 8])
    assert_equal(chain.call(4), [4, 5])


@fieldwise_init
struct PureView(Unary, _UnaryViewable):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    comptime _View[o: ImmOrigin] = _SharedUnaryRef[Self, o]
    def _unary_view[o: ImmOrigin](ref[o] self) -> Self._View[o]:
        return Self._View[o](Pointer(to=self))
    def call(self, var arg: Int) -> Int: return arg + self.amount


def check_shapes() raises:
    var pure = PureView(2)
    assert_equal(pipeline(3).then(pure).map(twice).get(), 10)
    assert_equal(pure.call(4), 6)
    def vector(value: Int) -> Optional[SIMD[DType.float32, 4]]:
        return Optional(SIMD[DType.float32, 4](value))
    var vectors = kleisli[OptionalFamily](vector)
    var total = pipeline(List[Int]([1, 2])).sum_by_effect(vectors).get()
    comptime assert type_of(total) == Optional[SIMD[DType.float32, 4]]
    assert_equal(total.value(), SIMD[DType.float32, 4](3))
    def choices(value: Int) -> List[Int]: return [value, -value]
    var branches = kleisli[ListFamily](choices)
    assert_equal(pipeline(List[Int]([1, 2])).sum_by_effect(branches).get(), [3, -1, 1, -3])
    def boxed(value: Int) -> Box[Float32]: return Box(Float32(value))
    var custom = kleisli[BoxMonad](boxed)
    var boxed_total = pipeline(List[Int]([1, 2])).sum_by_effect(custom).get().unwrap()
    comptime assert type_of(boxed_total) == Float32
    assert_equal(boxed_total, Float32(3))
    def rounded(value: Float64) -> Optional[Float64]: return Optional(value)
    var floats = kleisli[OptionalFamily](rounded)
    assert_equal(pipeline(List[Float64]([1e16, -1e16, 1])).sum_by_effect(floats).get().value(), 1.0)


def fail(value: Int) raises Int -> Optional[Int]: raise value


def check_errors() raises:
    var chain = kleisli[OptionalFamily](fail)
    var code = 0
    try: _ = pipeline(List[Int]([7])).raising[String]().sum_by_effect(chain).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 7)
    try: _ = pipeline(11).raising[String]().then(chain).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 11)


def check_origins(owner: List[Int], error_owner: List[Int]) raises:
    var view = Span(owner)
    var failure = Span(error_owner)
    comptime View = type_of(view)
    comptime Failure = type_of(failure)
    def keep(value: View) -> Optional[View]: return Optional(value)
    var chain = kleisli[OptionalFamily](keep)
    var kept = pipeline(view).then(chain).get()
    assert_true(Pointer(to=kept.value()[0]) == Pointer(to=owner[0]))
    def reject(value: View) {failure} -> Result[Int, Failure]: return Err(failure)
    var rejecting = kleisli[ResultFamily[Failure]](reject)
    var total = pipeline(List[View]([view])).sum_by_effect(rejecting).get()
    assert_true(Pointer(to=total._err().value[1]) == Pointer(to=error_owner[1]))


def forward[T: Movable & Deinitable, X: Movable & Deinitable](var value: Result[T, X]) raises X -> T:
    return pipeline(value^).raise_on_err()


def checked(value: Int) -> Result[Int, String]:
    if value < 0: return Err(String("negative"))
    return Ok(value)


def render(value: Int) -> String: return String(value)


def check_composed_terminal() raises:
    var chain = kleisli[ResultFamily[String]](checked).map(render)
    assert_equal(pipeline(3).then(chain).raise_on_err(), "3")
    assert_equal(forward(chain.call(4)), "4")
    var reason = String()
    try: _ = pipeline(-1).then(chain).raise_on_err()
    except error:
        comptime assert type_of(error) == String
        reason = error^
    assert_equal(reason, "negative")


def main() raises:
    check_composed_terminal()
    check_basics()
    check_shapes()
    check_errors()
    check_origins(List[Int]([7, 11]), List[Int]([13, 17]))
