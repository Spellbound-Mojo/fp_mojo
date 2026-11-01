# error: no matching function
from fp.functions import as_unary
from fp.iteration import count_where
def empty(var value: String) -> Bool: return value.byte_length() == 0
def main():
    var predicate = as_unary(empty)
    _ = count_where(List[String](), predicate)
