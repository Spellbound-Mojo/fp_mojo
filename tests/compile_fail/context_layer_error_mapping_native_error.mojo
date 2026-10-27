# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ListFamily, ResultFamily
from fp.effects import ResultT, OptionalT
from fp.data import Result, Ok, Err
def main():
    comptime I=ResultT[ListFamily,String]
    var code=1
    def stop(var error:String) raises Int {code}->Int:raise code
    _=pipeline[I](I.fail[Int](String("old"))).raising[String]().map_err(stop)
