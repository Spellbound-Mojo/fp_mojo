# error: use of uninitialized value
from fp.functions import pipeline
def main():
    var source = pipeline(Optional(1))
    _ = source^.product_l(Optional(2)).get()
    _ = source^.get()
