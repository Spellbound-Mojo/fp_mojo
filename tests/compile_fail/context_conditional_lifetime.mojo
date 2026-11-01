# error: use of uninitialized value
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.effects import Reader,run
from fp.callables import OnceThunk
def good() -> Optional[Int]: return Optional(1)
def main():
    comptime D=Reader[Int]
    var captured=String("x")
    def factory() {var captured^} -> D.Pure[Int]: return D.pure(captured.byte_length())
    var pending=pipeline[D](D.pure(True)).if_effect(factory,factory).get()
    var moved=factory^
    _ = moved()
    _ = run[D](pending^,0)
