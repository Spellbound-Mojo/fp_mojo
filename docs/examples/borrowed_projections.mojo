from fp.effects import Reader, State, LiftProject, OptionalT, asks, inspect, run
from std.testing import assert_equal

@fieldwise_init
struct Configuration(Movable):
    var port: Int
    var labels: List[String]

def server_port(config: Configuration) -> Int:
    return config.port

def main() raises:
    var config = Configuration(8080, [String("api")])
    var read_port = asks[Reader[Configuration]](server_port)
    var port = run[Reader[Configuration]](read_port^, config)
    assert_equal(port, 8080)
    print("reader port:", port)
    comptime Base = Reader[Configuration]
    comptime Selected = LiftProject[OptionalT[Base], Base]
    var lifted = asks[Selected](server_port)
    print("lifted port:", run[Base](lifted^, config).value())
    var state_port = inspect[State[Configuration]](server_port)
    var inspected = run[State[Configuration]](state_port^, config^)
    assert_equal(inspected[1].labels, [String("api")])
    print("state port:", inspected[0])
