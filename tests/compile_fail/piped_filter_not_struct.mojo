# error: no matching method in call to 'filter_not'
from fp.functions import pipeline

@fieldwise_init
struct FilterNotNotAContainer(Movable):
    var value: Int

def select(value: FilterNotNotAContainer) -> Bool: return value.value > 0

def main():
    _ = pipeline(FilterNotNotAContainer(1)).filter_not(select).get()
