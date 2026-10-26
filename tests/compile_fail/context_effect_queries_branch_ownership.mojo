# error: List callbacks must be repeatable
from fp.functions import pipeline
from fp.algebra import ListFamily
@fieldwise_init
struct Owner(Movable):
    var value: Int
def callback(value: Owner) -> List[Bool]: return List[Bool]([False,True])
def main():
    var source = List[Owner]()
    source.append(Owner(1))
    _ = pipeline(source^).find_effect[ListFamily](callback).get()
