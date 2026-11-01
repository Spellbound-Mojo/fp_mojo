# error: no matching method in call to 'map_n'
from fp.functions import pipeline
def wrong(var a: Int, var b: String) -> Int: return a
def main(): _ = pipeline(Optional(1)).map_n((Optional(2),), wrong).get()
