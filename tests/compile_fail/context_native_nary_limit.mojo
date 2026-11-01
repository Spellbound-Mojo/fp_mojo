# error: no matching method
from fp.functions import pipeline
def eight(var a:Int,var b:Int,var c:Int,var d:Int,var e:Int,var f:Int,var g:Int,var h:Int)->Int: return a+b+c+d+e+f+g+h
def main():
    var pointer:def(var Int,var Int,var Int,var Int,var Int,var Int,var Int,var Int) thin ->Int=eight
    _ = pipeline(Optional(1)).map_n((Optional(2),Optional(3),Optional(4),Optional(5),Optional(6),Optional(7),Optional(8),Optional(9)),pointer).get()
