# error: no matching method
# ResultFamily does not provide this capability; the callback is otherwise valid.
from fp.functions import pipeline
from fp.data import Result, Ok

def callback(value:Int) -> Bool: return True
def main():
    _ = pipeline(Result[Int,String](Ok(1))).filter(callback).get()
