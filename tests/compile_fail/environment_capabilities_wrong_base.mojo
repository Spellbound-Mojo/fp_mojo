# error: constraint
from fp.effects import Reader, StateT, LiftAsk, ask
def main(): _ = ask[LiftAsk[StateT[Reader[Int], Int], Reader[String]]]()
