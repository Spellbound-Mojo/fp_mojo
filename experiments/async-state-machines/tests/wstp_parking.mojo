"""Parking protocol: no lost work, the searcher bound, and one unpark per notification.

Workers on OS threads (`OSThread`) follow the `_Parking` protocol around a
shared external queue. They park in a test-only parker, a self-pipe per worker
waited on with `poll`; the pool's real parker belongs to the poller. The main
thread submits bursts, half of them only after every worker has parked, and
requires each burst to be consumed exactly once before a deadline.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from std.os import abort, getenv
from std.time import monotonic, sleep
from fp._internal.os import OSThread, POLLIN, Pipe, PollFd, poll
from fp.effects._async.scheduling.external_queue import _ExternalQueue
from fp.effects._async.scheduling.parking import _Parking
from fp.effects._async.scheduling.random import _Random
from wstp_support import check, Ledger, Tracked

comptime WORKERS = 4


struct ParkRig(Movable):
    var parking: _Parking
    var queue: _ExternalQueue[Tracked]
    var pipes: List[Pipe]
    var claims: Pointer[Atomic[Int], MutUntrackedOrigin]
    """Notifier claims of each worker's current parking."""
    var done: Atomic[Int]
    var admitted: Atomic[Int]
    var most_admitted: Atomic[Int]
    var claimed: Atomic[Int]
    var notified_wakes: Atomic[Int]
    var repeated_claims: Atomic[Int]
    var parks: Atomic[Int]

    def __init__(out self) raises:
        self.parking = _Parking(WORKERS)
        self.queue = _ExternalQueue[Tracked](WORKERS)
        self.pipes = List[Pipe]()
        for _ in range(WORKERS):
            self.pipes.append(Pipe.open_self_pipe())
        self.claims = unsafe_alloc[Atomic[Int]](WORKERS)
        for i in range(WORKERS):
            self.claims.unsafe_offset(i).unsafe_write(Atomic(0))
        self.done = Atomic(0)
        self.admitted = Atomic(0)
        self.most_admitted = Atomic(0)
        self.claimed = Atomic(0)
        self.notified_wakes = Atomic(0)
        self.repeated_claims = Atomic(0)
        self.parks = Atomic(0)

    def __deinit__(deinit self):
        self.claims.unsafe_free()

    def notify(mut self, mut random: _Random):
        """Wake one parked worker if the protocol asks for it, through its pipe."""
        var worker = self.parking.notify_parked(random)
        if worker < 0:
            return
        _ = self.claims[unsafe_offset=worker].fetch_add(1)
        _ = self.claimed.fetch_add(1)
        try:
            _ = self.pipes[worker].wake()
        except error:
            abort(String("wake failed: ", error))
        self.parking.finish_unpark(worker)


@fieldwise_init
struct ParkWorker(Movable):
    var rig: ArcPointer[ParkRig]
    var ledger: Ledger
    var index: Int

    def park(self) -> Bool:
        """Wait on this worker's pipe; True when notified, False at shutdown."""
        _ = self.rig[].parks.fetch_add(1)
        var descriptors = List[PollFd]()
        descriptors.append(PollFd(self.rig[].pipes[self.index].read_end.fd, POLLIN))
        while True:
            try:
                _ = poll(descriptors, 1000)
                _ = self.rig[].pipes[self.index].drain()
            except error:
                abort(String("park failed: ", error))
            if self.rig[].done.load[ordering=Ordering.ACQUIRE]() != 0:
                return False
            if self.rig[].parking.after_wake(self.index):
                if self.rig[].claims[unsafe_offset=self.index].load() != 1:
                    _ = self.rig[].repeated_claims.fetch_add(1)
                _ = self.rig[].notified_wakes.fetch_add(1)
                return True

    def prepare(self):
        # Reset before publishing the intent to park, which releases the reset.
        self.rig[].claims[unsafe_offset=self.index].store(0)
        self.rig[].parking.prepare_to_park(self.index)

    def run(self):
        var random = _Random(UInt64(self.index + 101))
        var searching = False
        var admitted = False
        while self.rig[].done.load[ordering=Ordering.ACQUIRE]() == 0:
            var item = self.rig[].queue.pop(random)
            if item:
                if searching:
                    if admitted:
                        _ = self.rig[].admitted.fetch_sub(1)
                    searching = False
                    admitted = False
                    if self.rig[].parking.transition_from_searching():
                        self.rig[].notify(random)
                # As upstream after taking external work: ask for help with the rest.
                if not self.rig[].queue.is_empty():
                    self.rig[].notify(random)
                spin(random.below(4000))
                self.ledger.receive(item.take())
                continue
            if not searching:
                if self.rig[].parking.transition_to_searching():
                    var now = self.rig[].admitted.fetch_add(1) + 1
                    _ = self.rig[].most_admitted.max(now)
                    searching = True
                    admitted = True
                    continue
                self.prepare()
                self.rig[].parking.transition_to_parked()
            else:
                if admitted:
                    _ = self.rig[].admitted.fetch_sub(1)
                self.prepare()
                if self.rig[].parking.transition_to_parked_when_searching():
                    if not self.rig[].queue.is_empty():
                        self.rig[].notify(random)
            admitted = False
            if not self.park():
                return
            # A notifier counted this worker active and searching.
            searching = True


@no_inline
def spin(nanoseconds: Int):
    """Simulated work, so that several workers are needed at once."""
    var until = Int(monotonic()) + nanoseconds
    while Int(monotonic()) < until:
        pass


def worker_body(state: Pointer[ParkWorker, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    state[].run()
    return None


def wait_for(label: String, ready: Bool, deadline: Int):
    if not ready and Int(monotonic()) > deadline:
        abort(label)


def parking_storm(bursts: Int, per_burst: Int) raises:
    var total = bursts * per_burst
    var ledger = Ledger(total)
    var rig = ArcPointer(ParkRig())
    var workers = List[OSThread[ParkWorker]]()
    for i in range(WORKERS):
        workers.append(OSThread(ArcPointer(ParkWorker(rig.copy(), ledger.copy(), i)), worker_body))
    var random = _Random(7)
    var next_id = 0
    var all_parked_bursts = 0
    for burst in range(bursts):
        if burst % 2 == 0:
            # Submit only once every worker has parked.
            var deadline = Int(monotonic()) + 5_000_000_000
            while rig[].parking.active() != 0:
                wait_for("workers did not all park", False, deadline)
                sleep(0.0001)
            all_parked_bursts += 1
        for _ in range(per_burst):
            rig[].queue.push(ledger.make(next_id), random)
            next_id += 1
            rig[].notify(random)
        var deadline = Int(monotonic()) + 5_000_000_000
        while ledger.received() < next_id:
            wait_for("work submitted to parked workers was lost", False, deadline)
            sleep(0.00002)
    rig[].done.store[ordering=Ordering.RELEASE](1)
    for i in range(WORKERS):
        _ = rig[].pipes[i].wake()
    while workers:
        _ = workers.pop().join()
    check(ledger.received() == total, "every element consumed")
    check(all_parked_bursts == (bursts + 1) // 2, "bursts after a full park")
    check(rig[].most_admitted.load() <= WORKERS // 2, "admitted searchers exceeded half the workers")
    check(rig[].most_admitted.load() >= 1, "no worker searched")
    check(rig[].repeated_claims.load() == 0, "a worker was unparked twice for one parking")
    check(rig[].notified_wakes.load() > 0 and rig[].parks.load() > 0, "the protocol was not exercised")
    # Claims never exceed wakes except for workers claimed while shutting down.
    check(rig[].claimed.load() >= rig[].notified_wakes.load() and rig[].claimed.load() <= rig[].notified_wakes.load() + WORKERS, "claims match wakes")
    _ = rig^
    ledger.verify("parking", True)


def main() raises:
    # WSTP_SCALE multiplies the workload for local soaks; qualification uses 1.
    var scale = max(1, atol(getenv("WSTP_SCALE", "1")))
    parking_storm(3000 * scale, 64)
    print("wstp_parking: no lost work after full parks, searcher bound, one unpark per notification")
