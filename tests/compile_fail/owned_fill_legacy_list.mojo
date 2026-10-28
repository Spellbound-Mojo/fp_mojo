# error: no matching method
from fp.functions import pipeline,piped
from fp.data import Result,Ok
from fp.algebra import ListFamily
from fp.iteration import iterated,fill
from std.collections import Array
from owned_fill_support import Box
def main():
    _=piped(List[Int]([1,2])).fill(Box(1))
