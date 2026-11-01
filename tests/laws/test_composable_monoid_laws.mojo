"""Identity and associativity of composed monoids for bounded integer inputs."""
from fp.algebra import ProductMonoid, IntSumMonoid, IntProductMonoid, OptionalMonoid, StringMonoid, DictMonoid
from std.testing import assert_equal


def main() raises:
    comptime P = ProductMonoid[IntSumMonoid, IntProductMonoid]
    for a in range(-3, 4):
        for b in range(-3, 4):
            for c in range(-3, 4):
                var x = (a, a)
                var y = (b, b)
                var z = (c, c)
                assert_equal(P.combine(P.empty(), x), x)
                assert_equal(P.combine(x, P.empty()), x)
                var xy = P.combine(x, y)
                var yz = P.combine(y, z)
                assert_equal(P.combine(xy, z), P.combine(x, yz))
    comptime O = OptionalMonoid[StringMonoid]
    for present in [False, True]:
        var a = Optional(String("a")) if present else Optional[String]()
        var left = O.combine(O.empty(), a.copy())
        var right = O.combine(a.copy(), O.empty())
        assert_equal(left, a)
        assert_equal(right, a)
        var ab = O.combine(a.copy(), Optional(String("b")))
        var bc = O.combine(Optional(String("b")), Optional(String("c")))
        assert_equal(O.combine(ab^, Optional(String("c"))), O.combine(a^, bc^))
