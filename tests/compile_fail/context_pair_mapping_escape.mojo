# error: origin_of(local_value)
from fp.callables import OnceUnary,call_once
from fp.effects.state import _MapFirst

@fieldwise_init
struct Keep[V:Movable & Deinitable](OnceUnary):
    comptime Arg=Self.V
    comptime Out=Self.V
    def call_once(deinit self,var value:Self.V)->Self.Out:return value^

def read_pointer[o:ImmOrigin](ref[o] value:Int)->Pointer[Int,o]:return Pointer(to=value)

def escape[o:ImmOrigin](ref[o] owner:Int)->Tuple[Pointer[Int,o],Int]:
    var local_value=3
    var view=read_pointer(local_value)
    return call_once(_MapFirst[Keep[type_of(view)],Int](Keep[type_of(view)]()),Tuple(view,1))

def main():
    var owner=0
    _=escape(owner)
