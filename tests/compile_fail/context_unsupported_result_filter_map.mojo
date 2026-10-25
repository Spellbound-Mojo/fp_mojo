# error: no matching method
# ResultFamily does not provide this capability; the callback is otherwise valid.
from fp.functions import pipeline
from fp.data import Result, Ok

def callback(var value:Int) -> Optional[Int]: return Optional(1)
def main():
    _ = pipeline(Result[Int,String](Ok(1))).filter_map(callback).get()
