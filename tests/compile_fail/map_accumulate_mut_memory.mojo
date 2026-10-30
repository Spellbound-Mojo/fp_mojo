# error: no matching function in call to 'map_accumulate'
from fp.iteration import map_accumulate
def step(mut a: String, var b: Int) -> Tuple[String,Int]: return (a.copy(),b)
def main(): _ = map_accumulate([1],String("carry"),step)
