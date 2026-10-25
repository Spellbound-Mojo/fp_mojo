# error: no matching function in call to 'attempt'
from fp.data import attempt

def update(var amount: Int, mut value: Int) raises String -> Int:
    value += amount
    if value < 0:
        raise String("negative")
    return value

def main():
    var value = 7
    _ = attempt[owned_mut=False](update, 3, value)
