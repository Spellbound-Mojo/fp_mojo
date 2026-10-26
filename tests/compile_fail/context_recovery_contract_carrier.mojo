# error: invalid call to 'recovered': violated constraint
from fp.algebra import ApplicativeError, RecoverContract
from fp.callables import UnaryContract
from fp.functions import piped

def recovered[I: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var source: V, var handler: H) raises RecoverContract[I,V,H].Error -> RecoverContract[I,V,H].Out where RecoverContract[I,V,H].Compatible:
    return piped(source^).recover[I](handler^).get()

from fp.algebra import ResultFamily
from fp.functions import Identity
from fp.data import Result, Err
def main():
    _ = recovered[ResultFamily[String]](Result[String,Int](Err(1)), Identity[String]())
