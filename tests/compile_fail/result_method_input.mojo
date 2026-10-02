# error: no matching method in call to 'map'
from fp.data import Result, Ok

def size(text: String) -> Int:
    return text.byte_length()

def main():
    var value: Result[Int, String] = Ok(3)
    _ = value^.map(size)
