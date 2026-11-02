"""Write pricing and ticket steps once, then run a checkout in two stack orders."""
from fp.callables import Unary
from fp.effects import Ask, Stateful, LiftAsk, LiftStateful, Reader, ReaderT, State, StateT, ask, modify, run
from fp.functions import pipeline
from std.testing import assert_equal


@fieldwise_init
struct Pricing(Copyable):
    var unit_price: Int
    var shipping: Int


@fieldwise_init
struct NextTicket(Unary, Copyable):
    comptime Arg = Int
    comptime Out = Int
    def call(self, var counter: Int) -> Int: return counter + 1


def read_pricing[C: Ask]() raises C.AskError -> C.Asked where C.AskAvailable and C.Environment == Pricing:
    return ask[C]()


def take_ticket[C: Stateful]() raises C.ModifyError[NextTicket] -> C.Modified[NextTicket] where C.StateType == Int and C.ModifyCompatible[NextTicket]:
    return modify[C](NextTicket())


def total(pricing: Pricing) -> Int:
    return pricing.unit_price * 3 + pricing.shipping


def main() raises:
    var pricing = Pricing(12, 5)
    comptime R = Reader[Pricing]
    comptime S = State[Int]

    # State over Reader: the ticket counter is the outer layer.
    comptime Outer = StateT[R, Int]
    var counted = pipeline[Outer](take_ticket[Outer]()).product_r(read_pricing[LiftAsk[Outer, R]]()).map(total).get()
    var reader = run[Outer](counted^, 10)
    var first = run[R](reader^, pricing)
    assert_equal(first[0], 41)
    assert_equal(first[1], 11)
    print("state over reader: total =", first[0], "; ticket =", first[1])

    # Reader over State: the same steps, with the selections exchanged.
    comptime Inner = ReaderT[S, Pricing]
    var priced = pipeline[Inner](take_ticket[LiftStateful[Inner, S]]()).product_r(read_pricing[Inner]()).map(total).get()
    var state = run[Inner](priced^, pricing)
    var second = run[S](state^, 10)
    assert_equal(second[0], 41)
    assert_equal(second[1], 11)
    print("reader over state: total =", second[0], "; ticket =", second[1])
