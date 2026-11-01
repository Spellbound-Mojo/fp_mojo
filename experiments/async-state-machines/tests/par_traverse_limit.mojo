"""Bounded traversals reject a limit below one at the call, before any IO exists.

Each check forks a child that calls the bounded function with limit 0 and
must abort with the function's own message; the parent reads the child's
output through a pipe and waits for it. A valid limit is accepted.
"""
from std.ffi import external_call, c_int
from std.os import abort
from fp.algebra import par_traverse_n, par_sequence_n, par_traverse_void_n
from fp._internal.os import Pipe, read
from fp.effects.async_runtime import IO, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def twice(var value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value * 2)


def call(which: Int, limit: Int):
    var values = List[Int]()
    values.append(1)
    if which == 0:
        _ = par_traverse_n(limit, values^, twice)
    elif which == 1:
        var programs = List[IO[Int, Int]]()
        programs.append(IO[Int, Int].pure(1))
        _ = par_sequence_n(limit, programs^)
    else:
        _ = par_traverse_void_n(limit, values^, twice)


def aborts_with(which: Int, expected: String) raises:
    var pipe = Pipe.open()
    var pid = external_call["fork", c_int]()
    check(pid >= 0, "fork")
    if pid == 0:
        # The abort's message and trace go to standard output and error.
        _ = external_call["dup2", c_int](pipe.write_end.fd, c_int(1))
        _ = external_call["dup2", c_int](pipe.write_end.fd, c_int(2))
        call(which, 0)
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
    check(not exited_cleanly, String(expected, ": the call must abort"))
    var text = String(from_utf8_lossy=Span(output))
    check(expected + ": limit must be at least 1" in text, String("the abort names the function: ", text))
    _ = read_end^


def main() raises:
    aborts_with(0, "par_traverse_n")
    aborts_with(1, "par_sequence_n")
    aborts_with(2, "par_traverse_void_n")
    var values = List[Int]()
    values.append(4)
    var accepted = run(par_traverse_n(1, values^, twice))
    check(accepted.take()._take_ok()[0] == 8, "a limit of one is accepted")
    print("par_traverse limit: a limit below one aborts at the call with the function's name")
