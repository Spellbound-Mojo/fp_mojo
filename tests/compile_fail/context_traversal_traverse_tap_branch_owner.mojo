# error: repeatable
from fp.functions import pipeline
from fp.algebra import ListFamily
@fieldwise_init
struct Owner(Movable):
    var id: Int
def callback(value: Owner) -> List[Bool]: return List[Bool]([False,True])
def main(): _ = pipeline(Optional(Owner(1))).traverse_tap[ListFamily](callback).get()
