"""Align unequal inputs without truncating either side."""
from fp.iteration import iterated
from fp.data import Ior, Left, Right, Both


def describe(var value: Ior[Int,Int]) -> String:
    if value.isa[Left[Int]](): return "left=" + String(value[Left[Int]].value)
    if value.isa[Right[Int]](): return "right=" + String(value[Right[Int]].value)
    var pair = value^.unwrap[Both[Int,Int]]()
    return "both=" + String(pair.left) + "," + String(pair.right)


def main():
    print(iterated(range(2)).align_with(range(10,11),describe).to_list())
    print(iterated(range(1)).align_with(range(10,13),describe).to_list())
    for pair in iterated(range(2)).pad_zip(range(10,11)):
        print("present:",Bool(pair[0]),Bool(pair[1]))
    var remaining = iterated(range(1))
    print("moved:", remaining^.align_with(range(10,11),describe).to_list())
