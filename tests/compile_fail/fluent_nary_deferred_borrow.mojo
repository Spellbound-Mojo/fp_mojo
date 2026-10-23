# error: uninitialized
from fp.functions import piped
from fp.effects import Reader,run
@fieldwise_init
struct NaryCapture(Movable):
    var text:String
def main():
    var owner=NaryCapture(String("captured"))
    def combine(a:Int,b:Int,c:Int) {var owner^} -> Int: return owner.text.byte_length()+a+b+c
    var effect=piped(Reader[Int].pure(1)).map_n[Reader[Int]]((Reader[Int].pure(2),Reader[Int].pure(3)),combine).get()
    var moved=combine^
    print(moved(4,5,6))
    _=run[Reader[Int]](effect^,0)
