# error: constraint
from fp.effects import Ref
@fieldwise_init
struct Owner(Movable):
    var value:Int
def main():
    _=Ref(Owner(1)).get[Error]()
