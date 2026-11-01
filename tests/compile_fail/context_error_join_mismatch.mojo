# error: no matching method in call to 'then'
from fp.functions import pipeline
def parse(var text: String) raises String -> Int: return text.byte_length()
def check(var value: Int) raises Int -> Int: return value
def main() raises:
    _ = pipeline(String("ab")).then(parse).then(check).get()
