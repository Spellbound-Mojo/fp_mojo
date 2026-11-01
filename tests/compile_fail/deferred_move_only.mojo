# error: Copyable
from fp.effects import Deferred
@fieldwise_init
struct Owner(Movable):
    var value:Int
def main():
    _=Deferred[Owner]()
