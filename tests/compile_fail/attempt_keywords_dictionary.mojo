# error: invalid call to 'kwargs'
# error: cannot be converted
from fp.data import Capture

def target(var **values: Int) -> Int:
    return len(values)

def main():
    var values: Dict[String, Int] = {"one": 3}
    _ = Capture.kwargs(**values^).run(target)
