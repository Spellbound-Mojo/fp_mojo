# error: no matching function in call to 'second'
from fp.functions import second
def main():
    var offset = 1
    def native(var value: Int) {offset} -> Int: return value + offset
    _ = second[String](native)
