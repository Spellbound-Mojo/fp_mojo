# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ListFamily, IdentityFamily
from fp.effects import ResultT
def size(var error:String)->Int:return error.byte_length()
def main():
    comptime I=ResultT[ListFamily,String]
    _=pipeline[I](I.fail[Int](String("old"))).map_err[Target=IdentityFamily](size)
