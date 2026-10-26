# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.effects import Reader,run
from fp.callables import OnceThunk
def good() -> Optional[Int]: return Optional(1)
def bad()->Optional[String]: return Optional(String("x"))
def main(): _ = pipeline(Optional(True)).if_effect(good,bad).get()
