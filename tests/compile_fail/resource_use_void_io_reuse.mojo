# error: use of uninitialized value
from fp.effects import pure_resource, lift_resource, run_io
def main():
    var program = lift_resource(pure_resource[Int](7)).use_void()
    _ = run_io(program^)
    _ = run_io(program^)
