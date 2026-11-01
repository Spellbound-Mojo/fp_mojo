# error: no matching function in call to 'find_effect'
from fp.iteration import find_effect
from fp.algebra import ListFamily
@fieldwise_init
struct Owner(Movable):
    var value:Int
def yes(value:Owner)->List[Bool]:return [True,False]
def main():
    var xs=List[Owner]()
    xs.append(Owner(1))
    _=find_effect[ListFamily](xs^,yes)
