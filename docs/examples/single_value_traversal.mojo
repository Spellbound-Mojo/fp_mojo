"""Single-value traversal can return move-only List payloads."""
from fp.algebra import ListFamily
from fp.functions import pipeline
from std.testing import assert_equal

@fieldwise_init
struct Ticket(Movable):
    var number:Int

def issue(var number:Int)->List[Ticket]:
    return ListFamily.pure(Ticket(number))

def main() raises:
    # The Optional source invokes issue once and wraps each returned Ticket.
    # No Cartesian accumulation or Ticket copies are needed.
    var tickets=pipeline(Optional(7)).traverse[ListFamily](issue).get()
    comptime assert type_of(tickets)==List[Optional[Ticket]]
    assert_equal(tickets[0].value().number,7)
    var absent=pipeline(Optional[Int]()).traverse[ListFamily](issue).get()
    assert_equal(len(absent),1)
    assert_equal(Bool(absent[0]),False)
    print("single traversal: ticket=",tickets[0].value().number,"; absent=",not Bool(absent[0]),sep="")
