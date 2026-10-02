# error: origin_of(self.value)
from fp.callables import OnceThunk
from fp.data import attempt_once


@fieldwise_init
struct Invalid[origin: ImmOrigin](OnceThunk):
    var value: String
    comptime Out = Pointer[String, Self.origin]
    def call_once(deinit self) -> Self.Out:
        return Pointer[String, ImmOrigin(origin_of(self.value))](to=self.value)


def main():
    var owner = String('external')
    _ = attempt_once(Invalid[origin_of(owner)](String('consumed')))
