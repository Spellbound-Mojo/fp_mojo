"""Collection shares traversal without restarting or over-pulling an iterator."""
from fp.data.result import Result, Ok, Err, collect_results
from std.iter import Iterator, IterableOwned
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.result_ownership import Trace, Token, trace

comptime Item = Result[Token,Token]


@fieldwise_init
struct Source(Iterator,IterableOwned):
    comptime Element = Item
    comptime IteratorOwnedType = Self
    var items: List[Optional[Item]]
    var index: Int
    var trace: ArcPointer[Trace]
    def __iter__(var self) -> Self:
        self.trace[].restarts += 1
        self.index = 0
        return self^
    def __next__(mut self) raises StopIteration -> Item:
        self.trace[].pulls += 1
        if self.index == len(self.items):
            raise StopIteration()
        var index = self.index
        self.index += 1
        return self.items[index].take()


def check(count:Int,failure:Int,skip:Bool) raises:
    var log = trace()
    var items = List[Optional[Item]]()
    for index in range(count):
        var token = Token(index,log)
        items.append(Optional(Item(Err(token^)) if index == failure else Item(Ok(token^))))
    var source = Source(items^,0,log)
    if skip:
        _ = source.__next__()
    var collected = collect_results(source^)
    comptime assert type_of(collected) == Result[List[Token],Token]
    assert_equal(log[].restarts,0)
    assert_equal(log[].pulls,failure+1 if failure >= 0 else count+1)
    var stored = -1
    var output = Optional[List[Token]]()
    try:
        output = Optional(collected^.raise_on_err())
    except error:
        # The successful prefix and unpulled tail are already destroyed.
        for index in range(count):
            assert_equal(log[].drops[index],Int(index != failure))
        stored = error.id
    if output:
        var values = output.take()
        assert_equal(len(values),count-Int(skip))
        for index in range(len(values)):
            assert_equal(values[index].id,index+Int(skip))
    assert_equal(stored,failure)
    for index in range(count):
        assert_equal(log[].drops[index],1)


def main() raises:
    check(0,-1,False)
    check(4,-1,False)
    check(4,-1,True)
    check(4,0,False)
    check(4,2,False)
    print("Result collection: order, first error, cursor and owned cleanup")
