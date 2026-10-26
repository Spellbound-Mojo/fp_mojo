from fp.functions import pipeline
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal

comptime R = Reader[Int]
def original(x: Int) -> R.Pure[Int]: return R.pure(x+1)
def replacement(x: Int) -> R.Pure[Int]: return R.pure(x+100)
def generate() -> List[Int]: return List[Int]([7,8])
def failed() raises String -> R.Pure[Int]: raise String("late")

def main() raises:
    var pointer: def(Int) thin -> R.Pure[Int] = original
    var pending = pipeline[R](R.pure(2)).flat_pair_with(pointer).get()
    pointer = replacement
    assert_equal(run[R](pending^, 0), (2,3))
    assert_equal(run[R](pipeline[R](R.pure(2)).flat_pair_with(pointer).get(),0), (2,102))
    var factory: def() thin -> List[Int] = generate
    assert_equal(pipeline(List[Int]([1,2])).followed_by(factory).get(), List[Int]([7,8,7,8]))
    var fail: def() raises String thin -> R.Pure[Int] = failed
    var delayed = pipeline[R](R.pure(1)).raising[String]().before(fail).get()
    var caught=False
    try: _=run[R](delayed^,0)
    except error:
        comptime assert type_of(error)==String
        caught=True
        assert_equal(error,"late")
    assert_equal(caught,True)
    var values = List[Int]([7,8])
    var view = Span(values)
    comptime V = type_of(view)
    def projection(x: V) -> Optional[V]: return Optional(x)
    var pair = pipeline(Optional(view)).flat_pair_with(projection).get()
    comptime assert type_of(pair)==Optional[Tuple[V,V]]
    assert_equal(pair.value()[0][0],7)
    assert_equal(pair.value()[1][1],8)
