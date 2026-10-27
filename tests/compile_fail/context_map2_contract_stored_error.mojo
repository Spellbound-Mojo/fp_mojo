# error: invalid call to 'forward': violated constraint
# error: constraint declared here evaluated to False
from context_map2_contract_support import forward, Keep, Add, OnceAdd, MoveLeft, MoveRight, MoveState
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok

def main(): _ = forward[ResultFamily[String]](OnceAdd(),Result[Int,String](Ok(1)),Result[Int,Int](Ok(2)))
