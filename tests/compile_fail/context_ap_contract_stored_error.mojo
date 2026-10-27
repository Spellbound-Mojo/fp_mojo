# error: invalid call to 'forward': violated constraint
# error: constraint declared here evaluated to False
from context_ap_contract_support import forward, Plus, Consuming, Missing, KeepMove, MoveState, View
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok

def main(): _ = forward[ResultFamily[String]](Result[Plus,String](Ok(Plus(1))),Result[Int,Int](Ok(2)))
