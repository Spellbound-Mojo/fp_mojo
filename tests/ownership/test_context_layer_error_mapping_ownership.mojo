"""Layer mapping owns both once handlers through execution or disposal."""
from fp.algebra import ResultFamily
from fp.effects import ResultT, OptionalT, Reader, run
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from test_shared_outcomes_ownership import SOOwner
from test_context_error_mapping_ownership import Mapping


def deferred(drops:ArcPointer[Int],calls:ArcPointer[Int],failed:Bool,throws:Bool,execute:Bool) raises ->Int:
    comptime R = Reader[Int]
    comptime I = ResultT[R,SOOwner]
    var source = I.fail[SOOwner](SOOwner(1,drops)) if failed else I.pure(SOOwner(1,drops))
    var pending = pipeline[I](source^).map_both(Mapping(SOOwner(2,drops),calls,1,throws),Mapping(SOOwner(3,drops),calls,10,throws)).get()
    assert_equal(drops[],0)
    assert_equal(calls[],0)
    if not execute:return 0
    try:
        var result = run[R](pending^,0)
        if result.is_ok():return result._ok().value.value
        return result._err().value.value
    except error:
        comptime assert type_of(error)==Int
        return error


def optional(drops:ArcPointer[Int],calls:ArcPointer[Int],branch:Int,throws:Bool)->Int:
    comptime I = OptionalT[ResultFamily[SOOwner]]
    comptime V = Result[Optional[SOOwner],SOOwner]
    var source:V
    if branch==0:source=Ok(Optional(SOOwner(1,drops)))
    elif branch==1:source=Err(SOOwner(1,drops))
    else:source=Ok(Optional[SOOwner]())
    try:
        var mapped=pipeline[I](source^).map_both(Mapping(SOOwner(2,drops),calls,1,throws),Mapping(SOOwner(3,drops),calls,10,throws)).get()
        if mapped.is_err():return mapped._err().value.value
        if mapped._ok().value:return mapped._ok().value.value().value
        return 0
    except error:
        comptime assert type_of(error)==Int
        return error


def main() raises:
    for failed in range(2):
        for throws in range(2):
            var drops=ArcPointer(0)
            var calls=ArcPointer(0)
            assert_equal(deferred(drops,calls,Bool(failed),Bool(throws),True),(771 if failed else 762) if throws else (3 if failed else 2))
            assert_equal(calls[],10 if failed else 1)
            assert_equal(drops[],3)
        var abandoned=ArcPointer(0)
        var skipped=ArcPointer(0)
        assert_equal(deferred(abandoned,skipped,Bool(failed),False,False),0)
        assert_equal(skipped[],0)
        assert_equal(abandoned[],3)
    for branch in range(3):
        for throws in range(2):
            var drops=ArcPointer(0)
            var calls=ArcPointer(0)
            assert_equal(optional(drops,calls,branch,Bool(throws)),0 if branch==2 else ((762 if branch==0 else 771) if throws else (2 if branch==0 else 3)))
            assert_equal(calls[],0 if branch==2 else 1 if branch==0 else 10)
            assert_equal(drops[],2 if branch==2 else 3)
