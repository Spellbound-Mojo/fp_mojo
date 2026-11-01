# error: uninitialized
from fp.functions import pipeline
from fp.effects import Reader, run
def main():
    comptime Deferred = Reader[Int]
    var value = String("capture")
    def callback(var a:Int,var b:String,var c:Int) {var value^} ->Int: return value.byte_length()+a+c
    var pending = pipeline[Deferred](Deferred.pure(1)).map_n((Deferred.pure(String("x")),Deferred.pure(3)),callback).get()
    var moved = callback^
    _ = moved(0, String(), 0)
    _ = run[Deferred](pending^,0)
