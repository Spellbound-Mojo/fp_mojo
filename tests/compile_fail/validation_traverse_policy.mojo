# error: constraint
from fp.functions import piped
from fp.algebra import StringMonoid
from fp.data import Result,Ok

def validate(a:Int)->Result[Int,List[String]]:return Ok(a)
def main():
    _=piped(List[Int]([1,2])).par_traverse[StringMonoid](validate)
