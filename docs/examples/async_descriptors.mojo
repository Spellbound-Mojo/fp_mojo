"""Wait for a file descriptor to become readable, as library authors build pipes and sockets."""
from std.ffi import external_call
from std.sys.info import platform_map
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Duration, run
from fp.effects.async_runtime.protocols import await_readable

comptime F_SETFL: Int32 = 4
comptime O_NONBLOCK = Int32(platform_map[T=Int, "O_NONBLOCK", linux=0o4000, macos=0x0004]())


def value[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    """The program's success value; a failure or cancellation aborts."""
    var success = outcome.take().to_optional()
    return success.take()


@fieldwise_init
struct ReadByte(OnceUnary):
    """After readiness, read the byte without blocking."""
    var fd: Int32
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        var byte = List[UInt8](length=1, fill=0)
        if external_call["read", Int](self.fd, byte.unsafe_ptr(), 1) != 1:
            return -1
        return Int(byte[0])


@fieldwise_init
struct WriteByte(OnceUnary):
    var fd: Int32
    var byte: UInt8
    comptime Arg = NoneType
    comptime Out = NoneType

    def call_once(deinit self, var unit: NoneType) -> NoneType:
        var data = List[UInt8](length=1, fill=self.byte)
        _ = external_call["write", Int](self.fd, data.unsafe_ptr(), 1)
        return None


def first_of(var pair: Tuple[Int, NoneType]) -> Int:
    return pair[0]


def main() raises:
    var fds = List[Int32](length=2, fill=-1)
    if external_call["pipe", Int32](fds.unsafe_ptr()) != 0:
        raise Error("pipe failed")
    var read_end = fds[0]
    var write_end = fds[1]
    # fcntl is variadic in C: two fixed arguments, then the flags, which ARM64
    # macOS passes differently from a fixed argument.
    _ = external_call["fcntl", Int32, num_fixed_args=2](read_end, F_SETFL, O_NONBLOCK)

    # The reader parks in the poller until the writer's byte arrives; it
    # does not poll on a timer. The caller keeps both ends open until the IO ends.
    var reader = await_readable[Int](RawFileDescriptor(read_end)).map(ReadByte(read_end))
    var writer = IO[NoneType, Int].sleep(Duration.milliseconds(5)).map(WriteByte(write_end, 42))
    print("read:", value(run(reader^.both(writer^).map(first_of))))

    _ = external_call["close", Int32](read_end)
    _ = external_call["close", Int32](write_end)
