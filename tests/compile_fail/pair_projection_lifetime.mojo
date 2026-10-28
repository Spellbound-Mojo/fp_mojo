# error: use of uninitialized value 'callback'
from fp.functions import first
from fp.iteration import iterated
def increment(value: Int) -> Int: return value + 1
def main():
    var callback = first[String](increment)
    var source: List[Tuple[Int, String]] = [(1, String("id"))]
    var pending = iterated(source^).map(callback)
    _ = callback^.call_once((2, String("id")))
    _ = pending^.collect_list()
