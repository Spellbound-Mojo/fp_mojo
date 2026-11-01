"""Polling system: interrupts racing a park, coalescing, readiness, removal, closing and timeouts.

Every cross-thread case uses OS threads (`OSThread`). `POLLER_SCALE`
multiplies the race rounds for local soaks; qualification uses 1.
"""
from std.atomic import Atomic
from std.ffi import ErrNo, c_int
from std.memory import ArcPointer
from std.os import abort, getenv
from std.time import monotonic, sleep
from fp._internal.os import OSThread, Pipe, RUSAGE_THREAD, getrusage, is_nonblocking, write
from fp._internal.time import Duration
from fp._internal.waking import Signal
from fp.effects._async.polling import READ_INTEREST, WRITE_INTEREST, _Interrupter, _Poller, _PollResult, _Registration
from fp.effects._async.scheduling.random import _Random

comptime millisecond = 1_000_000
comptime round_bound = 2_000_000_000
"""A round that takes longer than this has lost a wake."""


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


@no_inline
def spin(nanoseconds: Int):
    """Busy-wait, so delays below the scheduler's granularity are real."""
    var until = Int(monotonic()) + nanoseconds
    while Int(monotonic()) < until:
        pass


def nanoseconds(value: Int) raises -> Duration:
    return Duration.nanoseconds(value)


def released(fd: c_int) -> Bool:
    """True when the descriptor is closed (EBADF)."""
    try:
        _ = is_nonblocking(fd)
        return False
    except error:
        return error.errno == ErrNo.EBADF


# ===------------------------------------------------------------------=== #
# Interrupts racing a park
# ===------------------------------------------------------------------=== #


struct RaceState(Movable):
    var interrupter: _Interrupter
    var published: Atomic[Int]
    var acknowledged: Atomic[Int]
    var rounds: Int
    var seed: UInt64

    def __init__(out self, interrupter: _Interrupter, rounds: Int, seed: UInt64):
        self.interrupter = interrupter.copy()
        self.published = Atomic(0)
        self.acknowledged = Atomic(0)
        self.rounds = rounds
        self.seed = seed


def race_body(state: Pointer[RaceState, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    var random = _Random(state[].seed)
    for round in range(1, state[].rounds + 1):
        # Land the interrupt before the owner's check, between its check and
        # its poll, or during the poll.
        var choice = random.below(4)
        if choice == 1:
            spin(random.below(5_000))
        elif choice == 2:
            spin(random.below(60_000))
        elif choice == 3:
            sleep(Float64(random.below(300)) / 1e6)
        state[].published.store(round)
        state[].interrupter.interrupt()
        var deadline = Int(monotonic()) + round_bound
        while state[].acknowledged.load() < round:
            if Int(monotonic()) > deadline:
                abort("poller race: the owner never acknowledged a round")
    return None


def interrupts_race_a_park(rounds: Int) raises:
    var poller = _Poller()
    var race = OSThread(ArcPointer(RaceState(poller.interrupter(), rounds, 11)), race_body)
    var random = _Random(5)
    var woken_in_poll = 0
    var expired = 0
    for round in range(1, rounds + 1):
        var start = Int(monotonic())
        while True:
            var seen = race.state()[].published.load()
            if seen >= round:
                break
            # Widen the window between the re-check and the park.
            if random.below(2) == 0:
                spin(random.below(20_000))
            var result = poller.poll(nanoseconds(round_bound))
            check(not result.closed, "poller race: closed unexpectedly")
            if result.expired:
                expired += 1
            if result.interrupted and race.state()[].published.load() >= round:
                woken_in_poll += 1
            check(Int(monotonic()) - start < round_bound, "poller race: a wake was lost")
        if random.below(3) == 0:
            spin(random.below(20_000))
        race.state()[].acknowledged.store(round)
    _ = race^.join()
    check(expired == 0, "poller race: a poll expired, so a wake was lost")
    check(woken_in_poll > 0, "poller race: no poll was woken by an interrupt")
    print("interrupts racing a park: no lost wake in every round")


# ===------------------------------------------------------------------=== #
# Coalescing
# ===------------------------------------------------------------------=== #


@fieldwise_init
struct Hammer(Movable):
    var interrupter: _Interrupter
    var count: Int


def hammer_body(state: Pointer[Hammer, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    for _ in range(state[].count):
        state[].interrupter.interrupt()
    return None


def coalesced_interrupts() raises:
    var poller = _Poller()
    var threads = List[OSThread[Hammer]]()
    for _ in range(4):
        threads.append(OSThread(ArcPointer(Hammer(poller.interrupter(), 20_000)), hammer_body))
    for _ in range(1000):
        poller.interrupt()
    while threads:
        _ = threads.pop().join()
    var first = poller.poll(Duration())
    check(first.interrupted and first.wake_bytes == 1 and not first.expired, "coalesced: 81,000 interrupts write one byte and wake once")
    var second = poller.poll(Duration())
    check(second.expired and not second.interrupted and second.wake_bytes == 0, "coalesced: the wake was consumed")
    # The flag clears with the drain, so the next interrupt writes again.
    poller.interrupt()
    var third = poller.poll(nanoseconds(round_bound))
    check(third.interrupted and third.wake_bytes == 1, "coalesced: an interrupt after the drain wakes again")
    print("coalesced interrupts: one byte, one wake")


# ===------------------------------------------------------------------=== #
# Descriptor readiness and removal
# ===------------------------------------------------------------------=== #


@fieldwise_init
struct Writer(Movable):
    var fd: c_int
    var delay: Float64


def writer_body(state: Pointer[Writer, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    sleep(state[].delay)
    var byte = Array[UInt8, 1](fill=7)
    try:
        _ = write(state[].fd, Span(byte))
    except error:
        abort(String("writer: ", error))
    return None


def read_readiness() raises:
    var poller = _Poller()
    var data = Pipe.open_self_pipe()
    var signal = Signal()
    var revision = signal.revision()
    var registration = poller.register(data.read_end.fd, READ_INTEREST, signal).value()
    check(poller.needs_poll() and poller.has_registrations(), "read: armed")
    var idle = poller.poll(Duration())
    check(idle.expired and idle.ready == 0 and poller.readiness(registration).pending(), "read: nothing ready yet")
    check(signal.revision() == revision, "read: no notification before readiness")
    # Another thread writes while the owner is parked.
    var writer = OSThread(ArcPointer(Writer(data.write_end.fd, 0.01)), writer_body)
    var result = poller.poll(nanoseconds(round_bound))
    _ = writer^.join()
    check(result.ready == 1 and not result.expired and not result.interrupted, "read: readiness wakes the park")
    var readiness = poller.readiness(registration)
    check(readiness.ready() and readiness.events.readable() and not readiness.events.failed(), "read: readable")
    check(signal.revision() != revision, "read: the signal was notified")
    check(not poller.needs_poll() and poller.has_registrations(), "read: reported, awaiting removal")
    # Readiness is reported once, although the byte is still unread.
    var again = poller.poll(Duration())
    check(again.ready == 0 and again.expired, "read: reported once")
    check(poller.deregister(registration), "read: removed on completion")
    check(not poller.deregister(registration), "read: a second removal is stale")
    check(poller.readiness(registration).stale() and not poller.has_registrations(), "read: stale handle")
    _ = data.drain()
    _ = data^
    print("read readiness: notified once, removed on completion")


def write_readiness() raises:
    var poller = _Poller()
    var data = Pipe.open_self_pipe()
    var signal = Signal()
    var registration = poller.register(data.write_end.fd, WRITE_INTEREST, signal).value()
    var result = poller.poll(Duration())
    check(result.ready == 1 and poller.readiness(registration).events.writable(), "write: an empty pipe is writable")
    check(poller.deregister(registration), "write: removed")
    # Fill the pipe, so write interest waits.
    var chunk = List[UInt8](length=4096, fill=1)
    while True:
        try:
            _ = write(data.write_end.fd, Span(chunk))
        except error:
            check(error.is_again(), "write: filling stops at EAGAIN")
            break
    var revision = signal.revision()
    var full = poller.register(data.write_end.fd, WRITE_INTEREST, signal).value()
    var blocked = poller.poll(nanoseconds(5 * millisecond))
    check(blocked.expired and poller.readiness(full).pending(), "write: a full pipe is not writable")
    _ = data.drain()
    var freed = poller.poll(nanoseconds(round_bound))
    check(freed.ready == 1 and poller.readiness(full).events.writable() and signal.revision() != revision, "write: writable after draining")
    check(poller.deregister(full), "write: removed")
    # Both interests on one registration.
    var both = poller.register(data.write_end.fd, READ_INTEREST | WRITE_INTEREST, signal).value()
    check(poller.poll(Duration()).ready == 1 and poller.readiness(both).events.writable(), "write: combined interest")
    check(poller.deregister(both), "write: removed")
    # Keep the pipe open until every poll that watches it has returned.
    _ = data^
    print("write readiness: waits while full, notified when writable")


def removal_and_stale_handles() raises:
    var poller = _Poller()
    var data = Pipe.open_self_pipe()
    var canceled = Signal()
    var revision = canceled.revision()
    var first = poller.register(data.read_end.fd, READ_INTEREST, canceled).value()
    check(poller.deregister(first), "removal: canceled while armed")
    check(not poller.needs_poll() and not poller.has_registrations(), "removal: nothing armed")
    _ = write(data.write_end.fd, Span(Array[UInt8, 1](fill=1)))
    var result = poller.poll(Duration())
    check(result.ready == 0 and result.expired and canceled.revision() == revision, "removal: a canceled registration is never notified")
    # The slot is reused under a new generation; the old handle stays stale.
    var current = Signal()
    var second = poller.register(data.read_end.fd, READ_INTEREST, current).value()
    check(second.index == first.index and second.generation != first.generation, "removal: slot reused with a new generation")
    check(not poller.deregister(first) and poller.readiness(first).stale(), "removal: stale handle rejected")
    check(poller.readiness(second).pending(), "removal: the stale removal left the live one armed")
    check(poller.poll(Duration()).ready == 1 and poller.readiness(second).ready(), "removal: live registration reported")
    check(canceled.revision() == revision, "removal: only the live signal was notified")
    check(poller.deregister(second) and not poller.deregister(second), "removal: removed once")
    _ = data^
    print("registrations: removed on completion and cancellation, stale handles rejected")


# ===------------------------------------------------------------------=== #
# Closing
# ===------------------------------------------------------------------=== #


struct Closer(Movable):
    var interrupter: _Interrupter
    var delay: Float64
    var closed: Atomic[Int]

    def __init__(out self, interrupter: _Interrupter, delay: Float64):
        self.interrupter = interrupter.copy()
        self.delay = delay
        self.closed = Atomic(0)


def closer_body(state: Pointer[Closer, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    sleep(state[].delay)
    if state[].interrupter.close():
        state[].closed.store(1)
    return None


def close_during_poll() raises:
    var poller = _Poller()
    var pipe_fd = poller._pipe_descriptor()
    var data = Pipe.open_self_pipe()
    var signal = Signal()
    var revision = signal.revision()
    var registration = poller.register(data.read_end.fd, READ_INTEREST, signal).value()
    var closer = OSThread(ArcPointer(Closer(poller.interrupter(), 0.02)), closer_body)
    var result = poller.poll(None)
    var state = closer^.join()
    check(state[].closed.load() == 1, "close: the other thread's close won")
    check(result.closed, "close: a poll in progress returns closed")
    check(poller.readiness(registration).closed() and signal.revision() != revision, "close: an outstanding registration was notified")
    check(released(pipe_fd), "close: the pipe was released after the poll left")
    check(not poller.register(data.read_end.fd, READ_INTEREST, signal), "close: new registrations are rejected")
    var start = Int(monotonic())
    check(poller.poll(None).closed and Int(monotonic()) - start < round_bound, "close: polling a closed poller returns at once")
    # Interrupts and closes after closing do nothing.
    state[].interrupter.interrupt()
    check(not state[].interrupter.close() and state[].interrupter.is_closed(), "close: closed once")
    check(poller.deregister(registration) and not poller.has_registrations(), "close: removal after closing")
    _ = data^
    print("close during a poll: woken, registrations notified, pipe released")


def close_on_owner() raises:
    var poller = _Poller()
    var pipe_fd = poller._pipe_descriptor()
    var signal = Signal()
    var revision = signal.revision()
    var data = Pipe.open_self_pipe()
    var registration = poller.register(data.read_end.fd, READ_INTEREST, signal).value()
    var interrupter = poller.interrupter()
    poller.close()
    check(released(pipe_fd), "owner close: released at once with no poll in progress")
    check(poller.readiness(registration).closed() and signal.revision() != revision, "owner close: registration notified")
    check(poller.is_closed() and interrupter.is_closed(), "owner close: closed for every handle")
    _ = poller^
    # The handle outlives the poller.
    interrupter.interrupt()
    check(not interrupter.close(), "owner close: a late close does nothing")
    # Dropping a poller closes it and notifies what is still armed.
    var dropped = _Poller()
    var dropped_fd = dropped._pipe_descriptor()
    var second = Signal()
    var second_revision = second.revision()
    _ = dropped.register(data.read_end.fd, READ_INTEREST, second)
    _ = dropped^
    check(released(dropped_fd) and second.revision() != second_revision, "drop: closed, released and notified")
    _ = data^
    print("close on the owner and on drop: released once, registrations notified")


def close_racing_interrupts(rounds: Int) raises:
    var random = _Random(3)
    for _ in range(rounds):
        var poller = _Poller()
        var pipe_fd = poller._pipe_descriptor()
        var hammers = List[OSThread[Hammer]]()
        for _ in range(2):
            hammers.append(OSThread(ArcPointer(Hammer(poller.interrupter(), random.below(2_000))), hammer_body))
        var closer = OSThread(ArcPointer(Closer(poller.interrupter(), Float64(random.below(500)) / 1e6)), closer_body)
        var start = Int(monotonic())
        while not poller.poll(nanoseconds(round_bound)).closed:
            check(Int(monotonic()) - start < round_bound, "close race: close was lost")
        var state = closer^.join()
        check(state[].closed.load() == 1, "close race: closed once")
        while hammers:
            _ = hammers.pop().join()
        check(released(pipe_fd), "close race: released after every user left")
        _ = poller^
    print("close racing interrupts: released exactly once after every user left")


# ===------------------------------------------------------------------=== #
# Timeouts and idle CPU
# ===------------------------------------------------------------------=== #


def timeouts() raises:
    var poller = _Poller()
    var cases = List[Int]()
    for value in [0, 50_000, 200_000, 500_000, 900_000, millisecond, 2_500_000, 10 * millisecond]:
        cases.append(value)
    for timeout in cases:
        var start = Int(monotonic())
        var result = poller.poll(nanoseconds(timeout))
        var elapsed = Int(monotonic()) - start
        check(result.expired and not result.interrupted and result.ready == 0, "timeout: expired")
        check(elapsed >= timeout, String("timeout: returned early for ", timeout, " ns: ", elapsed))
        check(elapsed < timeout + 50 * millisecond, String("timeout: far too late for ", timeout, " ns: ", elapsed))
    # An interrupt pending before a sub-millisecond wait is seen at once.
    poller.interrupt()
    var result = poller.poll(nanoseconds(500_000))
    check(result.interrupted and not result.expired, "timeout: an interrupt beats a sub-millisecond deadline")
    print("timeouts: honored, including sub-millisecond deadlines")


def idle_poll_uses_no_cpu() raises:
    var poller = _Poller()
    var data = Pipe.open_self_pipe()
    _ = poller.register(data.read_end.fd, READ_INTEREST, Signal())
    var before = getrusage(RUSAGE_THREAD)
    var start = Int(monotonic())
    var result = poller.poll(nanoseconds(500 * millisecond))
    var elapsed = Int(monotonic()) - start
    var used = getrusage(RUSAGE_THREAD).total_nanoseconds() - before.total_nanoseconds()
    check(result.expired and elapsed >= 500 * millisecond, "idle: waited the whole timeout")
    check(used < 10 * millisecond, String("idle: a 500 ms poll used ", used, " ns of CPU"))
    _ = data^
    print("idle poll: no CPU over 500 ms")


def main() raises:
    var scale = max(1, atol(getenv("POLLER_SCALE", "1")))
    coalesced_interrupts()
    interrupts_race_a_park(3000 * scale)
    read_readiness()
    write_readiness()
    removal_and_stale_handles()
    close_during_poll()
    close_on_owner()
    close_racing_interrupts(100 * scale)
    timeouts()
    idle_poll_uses_no_cpu()
