# error: constraint
from fp.effects import Ref
def change(var value:Int)->Tuple[String,Int]:return (String("wrong"),value)
def main():
    _=Ref(1).modify[Error,Int](change)
