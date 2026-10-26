# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def callback() -> Optional[Bool]: return Optional(True)
def main(): _ = pipeline(List[String](["value"])).filter_effect[OptionalFamily](callback).get()
