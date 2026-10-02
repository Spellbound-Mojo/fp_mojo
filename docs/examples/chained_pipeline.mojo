"""An order total in ten stages: plain functions, closures and partials, chained."""
from fp.functions import piped, partial
from std.testing import assert_equal


@fieldwise_init
struct PriceError(Movable, Writable):
    var text: String


def parse_cents(text: String) raises PriceError -> Int:
    try:
        return atol(text)
    except:
        raise PriceError(text)


def multiply(factor: Int, cents: Int) -> Int: return factor * cents
def add(amount: Int, cents: Int) -> Int: return amount + cents
def not_negative(cents: Int) -> Int: return max(cents, 0)
def with_tax(cents: Int) -> Int: return cents + cents * 8 // 100
def to_nickel(cents: Int) -> Int: return (cents + 2) // 5 * 5


def dollars(cents: Int) -> String:
    var rest = cents % 100
    return "$" + String(cents // 100) + (".0" if rest < 10 else ".") + String(rest)


def label(amount: String) -> String: return "total: " + amount


def total(text: String, quantity: Int, percent: Int, shipping: Int) raises PriceError -> String:
    def discount(cents: Int) {imm percent} -> Int:
        return cents - cents * percent // 100
    def ship(cents: Int) {imm shipping} -> Int:
        return cents + shipping
    return (piped(text)
        .then(parse_cents)
        .then(partial(multiply, quantity))
        .then(discount)
        .then(partial(add, -500))
        .then(not_negative)
        .then(ship)
        .then(with_tax)
        .then(to_nickel)
        .then(dollars)
        .then(label)
        .get())


def main() raises:
    var receipt = total("1999", 3, 10, 499)
    assert_equal(receipt, "total: $58.30")
    print(receipt)
    try:
        _ = total("19.99", 3, 10, 499)
    except error:
        print("invalid price:", error.text)
