# error: use of uninitialized value 'values'
from fp.data import NonEmptyList
def main():
    var values = NonEmptyList(String("owned"))
    _ = values^.into_list()
    _ = values^.into_list()
