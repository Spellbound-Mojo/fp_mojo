# error: no matching function in call to 'local'
from fp.effects import Reader, action, local, run
from fp.callables import BorrowCallable

@fieldwise_init
struct Environment(Movable):
    var value: Int

@fieldwise_init
struct ReadEnvironment(BorrowCallable, Defaultable):
    comptime Payload = Environment
    comptime Result = Int
    def invoke(self, ref environment: Environment) raises Never capturing -> Int:
        return environment.value

def grow(value: Int) -> Int:
    return value + 1

def main() raises:
    var environment = Environment(5)
    var source = action[Reader[Environment], Int](ReadEnvironment())
    _ = run[Reader[Environment]](local[Reader[Environment]](grow, source^), environment)
