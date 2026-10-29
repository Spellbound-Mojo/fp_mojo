"""Read pricing configuration with Reader and scope a change with local."""
from fp.functions import pipeline
from fp.effects import Reader, ask, local
from std.testing import assert_equal


@fieldwise_init
struct TutorialPricing(Copyable):
    var unit_price: Int
    var shipping: Int


comptime PricingReader = Reader[TutorialPricing]


def free_shipping(pricing: TutorialPricing) -> TutorialPricing:
    return TutorialPricing(pricing.unit_price, 0)


def main() raises:
    var pricing = TutorialPricing(12, 5)
    var calls = 0

    def quote(var settings: TutorialPricing) {mut calls} -> Int:
        calls += 1
        return settings.unit_price * 3 + settings.shipping

    var standard = pipeline(ask[PricingReader]()).map(quote)
    assert_equal(calls, 0)
    print("before run: calls =", calls)
    var total = standard^.run(pricing)
    assert_equal(total, 41)
    assert_equal(calls, 1)
    print("standard total:", total)

    var quoted = pipeline(ask[PricingReader]()).map(quote).get()
    var promotion = local[PricingReader](free_shipping, quoted^)
    var discounted = pipeline(promotion^).run(pricing)
    assert_equal(discounted, 36)
    assert_equal(pricing.shipping, 5)
    assert_equal(calls, 2)
    print("free shipping total:", discounted, "; original shipping:", pricing.shipping)

    print("after both runs: calls =", calls)
