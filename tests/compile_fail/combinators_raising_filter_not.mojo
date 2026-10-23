# error: no matching method in call to 'filter_not'
from fp.iteration import iterated

def checked(value: Int) raises -> Bool:
    if value == 2: raise Error("stop")
    return value > 0

def main() raises:
    _ = iterated(range(3)).filter_not(checked).collect_list()
