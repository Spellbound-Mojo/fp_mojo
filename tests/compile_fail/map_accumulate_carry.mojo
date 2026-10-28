# error: no matching function in call to 'map_accumulate'
from fp.iteration import map_accumulate
def step(var a: Int, var b: Int) -> Tuple[String,Int]: return (String(a),b)
def main(): _ = map_accumulate(step,0,[1])
