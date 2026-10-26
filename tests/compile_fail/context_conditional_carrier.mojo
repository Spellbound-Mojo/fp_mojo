# error: branches of an eager family must have one carrier type
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.effects import Reader,run
from fp.callables import OnceThunk
def good() -> Optional[Int]: return Optional(1)
def bad()->List[Int]: return List[Int]([1])
def main(): _ = pipeline(Optional(True)).if_effect(good,bad).get()
