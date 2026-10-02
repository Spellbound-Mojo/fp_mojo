"""Result application preserves lazy scheduling, exact errors and consuming state."""
from fp.algebra import map2_lazy, ResultFamily, IdentityFamily, OptionalFamily, ListFamily
from fp.data import Result, Ok, Err
from fp.callables import OnceBinary, OnceThunk
from std.builtin.rebind import rebind_var
from std.testing import assert_equal
from algebra_support import Add, Next, ints
from algebra_support.result_ownership import Token, trace
from fp._internal.errors import _propagate_error

comptime Item = Result[Token,Token]


@fieldwise_init
struct NativeFailure(Movable):
    var token: Token


@fieldwise_init
struct Combine[raising:Bool](OnceBinary):
    var capture: Token
    var fail: Bool
    comptime First = Token
    comptime Second = Token
    comptime Out = Int
    comptime Error = NativeFailure if Self.raising else Never
    def call_once(deinit self,var left:Token,var right:Token) raises Self.Error -> Int:
        self.capture.trace[].calls += 1
        comptime if Self.raising:
            if self.fail:
                raise rebind_var[Self.Error](NativeFailure(Token(4,self.capture.trace)))
        return left.id*10+right.id


@fieldwise_init
struct Factory[raising:Bool](OnceThunk):
    var capture: Token
    var value: Item
    var fail: Bool
    comptime Out = Item
    comptime Error = NativeFailure if Self.raising else Never
    def call_once(deinit self) raises Self.Error -> Item:
        self.capture.trace[].factories += 1
        comptime if Self.raising:
            if self.fail:
                raise rebind_var[Self.Error](NativeFailure(Token(4,self.capture.trace)))
        return self.value^


def check[callback_raises:Bool,factory_raises:Bool](mode:Int) raises:
    var log = trace()
    var left = Item(Err(Token(0,log))) if mode == 1 else Item(Ok(Token(0,log)))
    var right = Item(Err(Token(1,log))) if mode == 2 else Item(Ok(Token(1,log)))
    var output = Optional[Result[Int,Token]]()
    var native = False
    try:
        output = Optional(map2_lazy[ResultFamily[Token]](
            Combine[callback_raises](Token(2,log),mode == 4),left^,
            Factory[factory_raises](Token(3,log),right^,mode == 3)))
    except error:
        comptime if callback_raises or factory_raises:
            comptime assert type_of(error) == NativeFailure
            native = True
            assert_equal(rebind[NativeFailure](error).token.id,4)
        else:
            comptime assert type_of(error) == Never
            _propagate_error[Never](error^)
    assert_equal(native,mode >= 3)
    assert_equal(log[].factories,Int(mode != 1))
    assert_equal(log[].calls,Int(mode == 0 or mode == 4))
    var stored = -1
    if output:
        var value = -1
        try:
            value = output.take().raise_on_err()
        except error:
            stored = error.id
        assert_equal(value,1 if mode == 0 else -1)
    assert_equal(stored,0 if mode == 1 else 1 if mode == 2 else -1)
    for index in range(4):
        assert_equal(log[].drops[index],1)
    assert_equal(log[].drops[4],Int(mode >= 3))


def main() raises:
    for mode in range(3):
        check[False,False](mode)
        check[True,True](mode)
    check[False,True](3)
    check[True,False](4)
    # Other native families keep their existing application semantics.
    assert_equal(map2_lazy[IdentityFamily](Add(),2,Next(3)),5)
    assert_equal(map2_lazy[OptionalFamily](Add(),Optional(2),Next(Optional(3))).value(),5)
    assert_equal(map2_lazy[ListFamily](Add(),ints(1,2),Next(ints(10,20))),ints(11,21,12,22))
    print("Result application: lazy branches, exact native errors and owned cleanup")
