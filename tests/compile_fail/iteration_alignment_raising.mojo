# error: no matching method in call to 'align_with'
from fp.iteration import iterated
from fp.data import Ior
def callback(var value: Ior[Int,Int]) raises -> Int: return 0
def main(): _ = iterated(range(2)).align_with(range(3), callback)
