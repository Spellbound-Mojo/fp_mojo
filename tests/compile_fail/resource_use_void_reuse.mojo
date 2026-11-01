# error: use of uninitialized value
from fp.effects import pure_resource
def main():
    var scope = pure_resource[Int](7)
    _ = scope^.use_void()
    _ = scope^.use_void()
