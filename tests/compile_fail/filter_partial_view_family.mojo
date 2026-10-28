# error: no matching function
from fp.functions import partial
from fp.algebra import filter, IdentityFamily

def below(limit: Int, value: Int) -> Bool: return value < limit
def main():
    var predicate = partial(below, 2)
    _ = filter[IdentityFamily](predicate, 1)
