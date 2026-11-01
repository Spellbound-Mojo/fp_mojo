# error: use of uninitialized value
from fp.effects import pure_resource, lift_resource
def main():
    var scope = lift_resource(pure_resource[Int](7))
    _ = scope^.use_void()
    _ = scope^.use_void()
