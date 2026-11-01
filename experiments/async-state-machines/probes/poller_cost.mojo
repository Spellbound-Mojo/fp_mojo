"""Cost of the poller's interrupt and of an empty nonblocking poll.

Build at O3 and run alone; numbers go to stdout in nanoseconds per operation:

    pixi run mojo build -O3 -I src experiments/async-state-machines/probes/poller_cost.mojo -o .cache/poller_cost
"""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.os import abort
from std.time import monotonic
from fp._internal.os import OSThread, Pipe
from fp._internal.time import Duration
from fp._internal.waking import Signal
from fp.effects._async.polling import READ_INTEREST, _Interrupter, _Poller


def per_operation(label: String, start: Int, count: Int):
    print(label, ":", (Int(monotonic()) - start) // count, "ns")


struct Pong(Movable):
    var mine: _Poller
    var theirs: _Interrupter
    var rounds: Int
    var ready: Atomic[Int]

    def __init__(out self, var mine: _Poller, theirs: _Interrupter, rounds: Int):
        self.mine = mine^
        self.theirs = theirs.copy()
        self.rounds = rounds
        self.ready = Atomic(0)


def pong_body(state: Pointer[Pong, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    try:
        state[].ready.store(1)
        for _ in range(state[].rounds):
            while not state[].mine.poll(None).interrupted:
                pass
            state[].theirs.interrupt()
    except error:
        abort(String("pong: ", error))
    return None


def main() raises:
    comptime count = 1_000_000
    var poller = _Poller()
    var zero = Duration()

    var start = Int(monotonic())
    for _ in range(count):
        _ = poller.poll(zero.copy())
    per_operation("poll(0), nothing registered", start, count)

    var pipes = List[Pipe]()
    for _ in range(16):
        pipes.append(Pipe.open_self_pipe())
    var watched = _Poller()
    for i in range(16):
        _ = watched.register(pipes[i].read_end.fd, READ_INTEREST, Signal())
    start = Int(monotonic())
    for _ in range(count):
        _ = watched.poll(zero.copy())
    per_operation("poll(0), 16 armed descriptors", start, count)
    _ = watched^
    _ = pipes^

    poller.interrupt()
    start = Int(monotonic())
    for _ in range(count):
        poller.interrupt()
    per_operation("interrupt(), coalesced (flag already set)", start, count)
    _ = poller.poll(zero.copy())

    start = Int(monotonic())
    for _ in range(count):
        poller.interrupt()
        _ = poller.poll(zero.copy())
    per_operation("interrupt() then poll(0) that drains it", start, count)

    comptime rounds = 50_000
    var ping = _Poller()
    # Take the handle before the poller moves to its owner thread.
    var pong_poller = _Poller()
    var theirs = pong_poller.interrupter()
    var pong = OSThread(ArcPointer(Pong(pong_poller^, ping.interrupter(), rounds)), pong_body)
    while pong.state()[].ready.load() == 0:
        pass
    start = Int(monotonic())
    for _ in range(rounds):
        theirs.interrupt()
        while not ping.poll(None).interrupted:
            pass
    per_operation("cross-thread wake round trip (two parks)", start, rounds)
    _ = pong^.join()
