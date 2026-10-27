# error: no matching
from fp.functions import pipeline
def text(var x: Int) -> Optional[String]: return Optional(String(x))
def main() raises:
    _ = pipeline(List[Int]([1])).fold_map_effect[Int](text)
