# error: no matching function in call to 'attempt_kwargs'
from fp.data import attempt_kwargs

def target(var **values: Int) -> Int:
    return len(values)

def main():
    var values: Dict[String, Int] = {"one": 3}
    _ = attempt_kwargs(target, **values^)
