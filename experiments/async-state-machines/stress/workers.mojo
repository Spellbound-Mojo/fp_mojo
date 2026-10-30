"""Repeated structured cancellation plus reuse of shared coordination handles."""
from fp._internal.cells import _lock_metadata
from fp.effects.async_runtime import Queue, Semaphore, both, pure, run
from workload import cycle
from support import Window, check


def main() raises:
    var window = Window()
    var queue = Queue[Int](2)
    var permits = Semaphore(2)
    var cycles = 0
    var queue_capacity = 0
    var queue_subscriptions = 0
    while window.more(cycles):
        # Reuse the established six-worker pipeline assertions: normal success,
        # timeout, withdrawal failure, and cancellation after external entry.
        cycle(cycles % 4)
        # These handles persist across roots. Both consumers park before the
        # producer runs; notifications and permits must be reusable indefinitely.
        var consumers = both(queue.take[Int](), queue.take[Int]())
        var producers = both(queue.offer[Int](cycles), queue.offer[Int](-cycles))
        var transferred = run(both(consumers^, producers^))
        var result = transferred.take()._take_ok()
        check(result[0][0] + result[0][1] == 0, "shared queue transfers both values")
        var limited = run(permits.with_permit(pure[Int](cycles)))
        var available = run(permits.available[Int]())
        check(limited.take()._take_ok() == cycles and available.take()._take_ok() == 2, "shared semaphore restores permits")
        var guard = _lock_metadata(queue._source._state._cell)
        ref values = guard.cell[].slot.value()
        check(len(values) == 0, "shared queue drains each cycle")
        if cycles == 0:
            queue_capacity = values._capacity
        check(values._capacity == queue_capacity, "shared queue allocation capacity plateaus")
        _ = guard^
        var signal = _lock_metadata(queue._source._state._changed._cell)
        ref waiters = signal.cell[].slot.value()
        check(waiters.active == 0 and len(waiters.entries) <= 2, "queue wait registrations reused and retired")
        if cycles == 0:
            queue_subscriptions = waiters.entries.capacity()
        check(waiters.entries.capacity() == queue_subscriptions, "shared queue subscription capacity plateaus")
        _ = signal^
        var semaphore = _lock_metadata(permits._source._state._changed._cell)
        check(semaphore.cell[].slot.value().active == 0, "permit registrations retired")
        cycles += 1
    print("stress workers", "cycles=" + String(cycles), "elapsed_ns=" + String(window.elapsed()),
          "queue_capacity=" + String(queue_capacity), "subscription_capacity=" + String(queue_subscriptions),
          "modes=4", "active=0", "live_timers=0", flush=True)
