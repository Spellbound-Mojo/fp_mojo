# error: no matching method
from fp.functions import pipeline, flow

def add(value: Int) -> Int: return value + 1
def double(value: Int) -> Int: return value * 2
def main():
    var chain = flow(add, double)
    _ = pipeline(String("wrong")).map(chain).get()
