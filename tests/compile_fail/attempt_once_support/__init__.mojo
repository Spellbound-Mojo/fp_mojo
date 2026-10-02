from fp.callables import OnceThunk


@fieldwise_init
struct Consume(OnceThunk):
    var bias: Int
    var value: Int
    comptime Out = Int
    def call_once(deinit self) -> Int:
        return self.bias + self.value


@fieldwise_init
struct Reference[origin: ImmOrigin](OnceThunk):
    var pointer: Pointer[String, Self.origin]
    comptime Out = Pointer[String, Self.origin]
    def call_once(deinit self) -> Self.Out:
        return self.pointer
