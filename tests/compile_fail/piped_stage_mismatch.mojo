# error: no matching method in call to 'then'
# error: expected 'identical(F.Value, Value)'
from fp.functions import piped

def twice(value: Int) -> Int:
    return value * 2

def size(text: String) -> Int:
    return text.byte_length()

def main():
    _ = piped(3).then(twice).then(size).get()
