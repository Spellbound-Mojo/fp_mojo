"""Runtime.run on one of the runtime's own workers aborts with its message.

A forked child creates a work-stealing runtime and runs a program whose step
calls `run` again on a copy of the same runtime, from the worker running it;
the child must abort with the runtime's message, which the parent reads
through a pipe. The same nested call on another runtime is accepted: it
blocks that worker until the inner program completes.
"""
from std.ffi import external_call, c_int
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, IORuntimeConfig, Profile, Runtime
from fp._internal.os import Pipe, read


def check(condition: Bool, message: String):
    if not condition:
        abort(String("runtime own worker: ", message))


def stealing() -> IORuntimeConfig:
    var config = IORuntimeConfig()
    try:
        config.profile = Profile.work_stealing(2)
    except:
        abort("a valid worker count")
    return config^


@fieldwise_init
struct RunInside(OnceUnary):
    """Call `run` on a runtime from inside a program step."""
    var runtime: Runtime
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        var inner = self.runtime.run(IO[Int, Int].pure(value + 1))
        check(Bool(inner) and inner.value().is_ok(), "the inner program succeeds")
        return IO[Int, Int].pure(inner.take()._take_ok())


def nested_on_own_worker():
    var runtime: Runtime
    try:
        runtime = Runtime(stealing())
    except:
        abort("the runtime starts")
    _ = runtime.run(IO[Int, Int].pure(1).flat_map(RunInside(runtime.copy())))


def aborts_on_own_worker() raises:
    var pipe = Pipe.open()
    var pid = external_call["fork", c_int]()
    check(pid >= 0, "fork")
    if pid == 0:
        # The abort's message and trace go to standard output and error.
        _ = external_call["dup2", c_int](pipe.write_end.fd, c_int(1))
        _ = external_call["dup2", c_int](pipe.write_end.fd, c_int(2))
        nested_on_own_worker()
        # Reached only if the call did not abort.
        external_call["_exit", NoneType](c_int(0))
    # The parent keeps only the read end, so the child's exit ends the reads.
    var read_end = pipe^.into_read_end()
    var output = List[UInt8]()
    var buffer = List[UInt8](length=4096, fill=0)
    while True:
        var count = read(read_end.fd, Span(buffer))
        if count <= 0:
            break
        for index in range(count):
            output.append(buffer[index])
    var status = c_int(0)
    _ = external_call["waitpid", c_int](pid, Pointer(to=status), c_int(0))
    # WIFEXITED is (status & 0x7f) == 0; the child must not exit normally with 0.
    var exited_cleanly = (Int(status) & 0x7F) == 0 and ((Int(status) >> 8) & 0xFF) == 0
    check(not exited_cleanly, "run on the runtime's own worker must abort")
    var text = String(from_utf8_lossy=Span(output))
    check("Runtime.run was called on one of the runtime's own workers" in text, String("the abort names the misuse: ", text))
    _ = read_end^


def main() raises:
    aborts_on_own_worker()
    var outer = Runtime(stealing())
    var other = Runtime(stealing())
    var outcome = outer.run(IO[Int, Int].pure(1).flat_map(RunInside(other.copy())))
    check(Bool(outcome) and outcome.value().is_ok() and outcome.take()._take_ok() == 2, "run on another runtime's worker blocks and completes")
    print("runtime own worker: run on the runtime's own worker aborts with its message; another runtime's worker may call run")
