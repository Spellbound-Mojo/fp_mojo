# error: no matching function in call to
from fp.iteration import map
from std.iter import iter

def failing(var value: Int) raises Int -> Int:
    raise value

def main():
    _ = map(failing, iter(range(3)))
