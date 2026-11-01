# error: no matching method in call to 'then'
from fp.functions import pipeline

def twice(value: Int) -> Int:
    return value * 2

def size(text: String) -> Int:
    return text.byte_length()

def main():
    _ = pipeline(3).then(twice).then(size).get()
