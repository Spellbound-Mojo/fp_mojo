# error: use of uninitialized value 'value'
from fp.data import Ior, Right
def main():
    var value: Ior[String, String] = Right(String("owned"))
    _ = value^.unwrap[Right[String]]()
    _ = value^.unwrap[Right[String]]()
