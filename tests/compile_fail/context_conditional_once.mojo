# error: List callbacks must be repeatable
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.effects import Reader,run
from fp.callables import OnceThunk
def good() -> Optional[Int]: return Optional(1)
@fieldwise_init
struct Once(OnceThunk):
    comptime Out=List[Int]
    def call_once(deinit self)->Self.Out: return List[Int]([1])
def main(): _ = pipeline(List[Bool]([True,False])).if_effect(Once(),Once()).get()
