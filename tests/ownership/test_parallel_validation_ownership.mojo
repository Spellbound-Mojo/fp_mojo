"""Validation moves successes, errors and callback owners without copies."""
from fp.algebra import Semigroup
from fp.callables import MutableUnary, OnceUnary
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.iteration import iterated
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct PVOwned(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct PVProduce(MutableUnary):
    var success_drops: ArcPointer[Int]
    var error_drops: ArcPointer[Int]
    var owner: PVOwned
    comptime Arg = Int
    comptime Out = Result[PVOwned,List[PVOwned]]
    def call_mut(mut self, var arg: Int) -> Self.Out:
        if arg < 0:
            var errors = List[PVOwned]()
            errors.append(PVOwned(arg,self.error_drops))
            return Err(errors^)
        return Ok(PVOwned(arg,self.success_drops))


@fieldwise_init
struct PVOwnedConstructor(OnceUnary):
    var owner: PVOwned
    comptime Arg = Tuple[PVOwned,PVOwned]
    comptime Out = Int
    def call_once(deinit self, var arg: Self.Arg) -> Int:
        return arg[0].id+arg[1].id+self.owner.id


struct PVOwnedMerge(Semigroup):
    comptime Value=List[PVOwned]
    comptime Error=PVOwned
    @staticmethod
    def combine(var left:Self.Value,var right:Self.Value) raises Self.Error -> Self.Value:
        raise PVOwned(left[0].id+right[0].id,left[0].drops)

def pvo_three(var a:PVOwned,var b:PVOwned,var c:PVOwned)->Int:return a.id+b.id+c.id


def pvo_failure(var a:PVOwned,var b:PVOwned) raises PVOwned -> Int:
    raise PVOwned(a.id+b.id,a.drops)


def pvo_traverse(success:ArcPointer[Int],errors:ArcPointer[Int],owners:ArcPointer[Int]) raises:
    var result = iterated(List[Int]([1,-2,3,-4,5])).par_traverse(PVProduce(success,errors,PVOwned(0,owners)))
    assert_equal(success[],3)
    assert_equal(owners[],1)
    assert_equal(errors[],0)
    assert_equal(result._err().value[0].id,-2)
    assert_equal(result._err().value[1].id,-4)


def pvo_conveniences() raises:
    var success = ArcPointer(0)
    var errors = ArcPointer(0)
    comptime R = Result[PVOwned,List[PVOwned]]
    var product = pipeline(R(Ok(PVOwned(1,success)))).par_product_n((R(Ok(PVOwned(2,success))),)).get()
    assert_equal(product._ok().value[1].id,2)
    assert_equal(success[],0)
    _ = product^
    assert_equal(success[],2)
    var items = List[R]()
    items.append(R(Ok(PVOwned(3,success))))
    items.append(R(Ok(PVOwned(4,success))))
    var collected = pipeline(items^).par_sequence().get()
    assert_equal(collected._ok().value[1].id,4)
    assert_equal(success[],2)
    _ = collected^
    assert_equal(success[],4)
    # Errors and successes move, even after a stored failure.
    var left = List[PVOwned]()
    left.append(PVOwned(5,errors))
    var right = List[PVOwned]()
    right.append(PVOwned(6,errors))
    var failed = List[R]()
    failed.append(R(Ok(PVOwned(7,success))))
    failed.append(R(Err(left^)))
    failed.append(R(Ok(PVOwned(8,success))))
    failed.append(R(Err(right^)))
    var accumulated = iterated(failed^).par_sequence()
    assert_equal(success[],6)
    assert_equal(errors[],0)
    assert_equal(accumulated._err().value[0].id,5)
    assert_equal(accumulated._err().value[1].id,6)
    _ = accumulated^
    assert_equal(errors[],2)
    # A raising policy drops its two inputs and the unvisited operand slot.
    var first = List[PVOwned]()
    first.append(PVOwned(1,errors))
    var second = List[PVOwned]()
    second.append(PVOwned(2,errors))
    var code = 0
    try:
        _ = pipeline(R(Err(first^))).par_product_n[PVOwnedMerge]((R(Err(second^)),R(Ok(PVOwned(9,success))))).get()
    except error:
        comptime assert type_of(error) == PVOwned
        code = error.id
    assert_equal(code,3)
    assert_equal(errors[],5)
    assert_equal(success[],7)
    # The iterator's unvisited owned elements are also cleaned up on a raise.
    var third = List[PVOwned]()
    third.append(PVOwned(3,errors))
    var fourth = List[PVOwned]()
    fourth.append(PVOwned(4,errors))
    var pending = List[R]()
    pending.append(R(Err(third^)))
    pending.append(R(Err(fourth^)))
    pending.append(R(Ok(PVOwned(10,success))))
    try:
        _ = iterated(pending^).par_sequence[PVOwnedMerge]()
    except error:
        comptime assert type_of(error) == PVOwned
        code = error.id
    assert_equal(code,7)
    assert_equal(errors[],8)
    assert_equal(success[],8)


def main() raises:
    pvo_conveniences()
    var success=ArcPointer(0)
    var errors=ArcPointer(0)
    var owners=ArcPointer(0)
    pvo_traverse(success,errors,owners)
    assert_equal(errors[],2)
    comptime R=Result[PVOwned,List[PVOwned]]
    var joined=pipeline(R(Ok(PVOwned(1,success)))).par_map_n((R(Ok(PVOwned(2,success))),),PVOwnedConstructor(PVOwned(3,owners))).get()
    assert_equal(joined._ok().value,6)
    assert_equal(success[],5)
    assert_equal(owners[],2)
    var failures=List[PVOwned]()
    failures.append(PVOwned(7,errors))
    var skipped=pipeline(R(Ok(PVOwned(9,success)))).par_map_n((R(Err(failures^)),),PVOwnedConstructor(PVOwned(8,owners))).get()
    assert_true(skipped.is_err())
    assert_equal(success[],6)
    assert_equal(owners[],3)
    _=skipped^
    assert_equal(errors[],3)
    var code=0
    try:
        _=pipeline(R(Ok(PVOwned(2,success)))).par_map_n((R(Ok(PVOwned(3,success))),),pvo_failure).get()
    except error:
        comptime assert type_of(error)==PVOwned
        code=error.id
    assert_equal(code,5)
    assert_equal(success[],9)
    # Accumulated errors, current successes and the callback are all dropped
    # when a later native callback raises.
    def raised(value:Int) raises PVOwned {success,errors} -> R:
        if value==3: raise PVOwned(3,success)
        if value<0:
            var es=List[PVOwned]()
            es.append(PVOwned(value,errors))
            return Err(es^)
        return Ok(PVOwned(value,success))
    try:
        _=pipeline(List[Int]([1,-2,3,4])).raising[PVOwned]().par_traverse(raised).get()
    except error:
        comptime assert type_of(error)==PVOwned
        code=error.id
    assert_equal(code,3)
    assert_equal(success[],11)
    assert_equal(errors[],4)
    var left=List[PVOwned]()
    left.append(PVOwned(1,errors))
    var right=List[PVOwned]()
    right.append(PVOwned(2,errors))
    try:
        _=pipeline(R(Err(left^))).par_map_n[PVOwnedMerge]((R(Err(right^)),R(Ok(PVOwned(3,success)))),pvo_three).get()
    except error:
        comptime assert type_of(error)==PVOwned
        code=error.id
    assert_equal(code,3)
    assert_equal(errors[],7)
    assert_equal(success[],12)
    print('parallel validation ownership: ok')
