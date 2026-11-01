# error: no matching method
from fp.effects.async_runtime import IO, Resource
def release(values: List[Int]) -> IO[NoneType, Int]:
    return IO[NoneType, Int].pure(NoneType())
def escape[o: ImmOrigin](ref[o] values: List[Int]) -> Span[Int, o]:
    return Span(values)
def main():
    var values: List[Int] = [1]
    _ = Resource[List[Int], Int].make(IO[List[Int], Int].pure(values^), release).map(escape)
