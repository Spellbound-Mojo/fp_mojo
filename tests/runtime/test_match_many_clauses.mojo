"""`fp.match` with sixteen clauses, the most it accepts."""
import fp
from fp.adt import Data, Cases, Node, Value
from std.testing import assert_equal


@fieldwise_init
struct ManyK0(Copyable):
    var v: Int
@fieldwise_init
struct ManyK1(Copyable):
    var v: Int
@fieldwise_init
struct ManyK2(Copyable):
    var v: Int
@fieldwise_init
struct ManyK3(Copyable):
    var v: Int
@fieldwise_init
struct ManyK4(Copyable):
    var v: Int
@fieldwise_init
struct ManyK5(Copyable):
    var v: Int
@fieldwise_init
struct ManyK6(Copyable):
    var v: Int
@fieldwise_init
struct ManyK7(Copyable):
    var v: Int
@fieldwise_init
struct ManyK8(Copyable):
    var v: Int
@fieldwise_init
struct ManyK9(Copyable):
    var v: Int
@fieldwise_init
struct ManyK10(Copyable):
    var v: Int
@fieldwise_init
struct ManyK11(Copyable):
    var v: Int
@fieldwise_init
struct ManyK12(Copyable):
    var v: Int
@fieldwise_init
struct ManyK13(Copyable):
    var v: Int
@fieldwise_init
struct ManyK14(Copyable):
    var v: Int
@fieldwise_init
struct ManyPair[R: Value](Movable):
    var a: Self.R
    var b: Self.R


struct ManyData(Data):
    comptime Layer[R: Value] = Cases[ManyK0, ManyK1, ManyK2, ManyK3, ManyK4, ManyK5, ManyK6, ManyK7,
                                     ManyK8, ManyK9, ManyK10, ManyK11, ManyK12, ManyK13, ManyK14, ManyPair[R]]


comptime M = Node[ManyData]


def code(m: M) -> Int:
    return fp.match(m,
        lambda (k: ManyK0) -> Int: k.v, lambda (k: ManyK1) -> Int: k.v + 1, lambda (k: ManyK2) -> Int: k.v + 2,
        lambda (k: ManyK3) -> Int: k.v + 3, lambda (k: ManyK4) -> Int: k.v + 4, lambda (k: ManyK5) -> Int: k.v + 5,
        lambda (k: ManyK6) -> Int: k.v + 6, lambda (k: ManyK7) -> Int: k.v + 7, lambda (k: ManyK8) -> Int: k.v + 8,
        lambda (k: ManyK9) -> Int: k.v + 9, lambda (k: ManyK10) -> Int: k.v + 10, lambda (k: ManyK11) -> Int: k.v + 11,
        lambda (k: ManyK12) -> Int: k.v + 12, lambda (k: ManyK13) -> Int: k.v + 13, lambda (k: ManyK14) -> Int: k.v + 14,
        lambda (p: ManyPair[Int]) -> Int: p.a * 100 + p.b)


def main() raises:
    assert_equal(code(M(ManyPair(M(ManyK3(1)), M(ManyK14(1))))), 415)
    assert_equal(code(M(ManyK0(9))), 9)
    assert_equal(code(M(ManyK7(0))), 7)
