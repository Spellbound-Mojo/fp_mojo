"""A changed Reader environment need not be Copyable for eager execution."""
from fp.algebra import pure, flat_map
from fp.effects import Reader, action, local, run
from fp.callables import BorrowCallable, as_unary
from std.testing import assert_equal

@fieldwise_init
struct Environment(Movable):
    var value:Int

@fieldwise_init
struct ReadEnvironment(BorrowCallable,Defaultable):
    comptime Payload=Environment
    comptime Result=Int
    def invoke(self,ref environment:Environment) raises Never capturing -> Int:
        return environment.value

@fieldwise_init
struct ChangeEnvironment(BorrowCallable,Defaultable):
    comptime Payload=Environment
    comptime Result=Environment
    def invoke(self,ref environment:Environment) raises Never capturing -> Environment:
        return Environment(environment.value+2)

def next_value(var value:Int)->type_of(pure[Reader[Environment]](Int())):
    return pure[Reader[Environment]](value+3)

def main() raises:
    comptime assert not conforms_to(Environment,Copyable)
    var environment=Environment(5)
    var endpoint=action[Reader[Environment],Int](ReadEnvironment())
    assert_equal(endpoint^.run(environment),5)
    var source=action[Reader[Environment],Int](ReadEnvironment())
    var composed=flat_map[Reader[Environment]](as_unary(next_value),source^)
    var changed=local[Reader[Environment]](ChangeEnvironment(),composed^)
    assert_equal(run[Reader[Environment]](changed^,environment),10)
    assert_equal(environment.value,5)
    print("Reader local: borrowed move-only environment")
