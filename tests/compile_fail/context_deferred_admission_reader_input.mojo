# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader

def wrong(var value: String) -> Int: return value.byte_length()

def main():
    _ = pipeline[Reader[Int]](Reader[Int].pure(1)).map(wrong).get()
