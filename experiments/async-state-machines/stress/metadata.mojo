"""Sustained reuse of one registry and one signal, including stale handles."""
from fp._internal.waking import _Runtime
from fp._internal.cells import _lock_metadata
from fp.effects.async_runtime import Clock, Duration
from fp.effects.async_runtime.protocols import Signal
from support import Window, check


def main() raises:
    var window = Window()
    var runtime = _Runtime()
    var event = Signal()
    var clock = Clock.manual(Int.MAX)
    var tick = Duration.nanoseconds(1)
    var parent = runtime.allocate(None, 0)
    runtime.begin(parent)
    runtime.arm(parent, False, None)
    var cycles = 0
    var node_capacity = 0
    var free_capacity = 0
    var subscription_capacity = 0
    var timers_peak = 0
    while window.more(cycles):
        var a = runtime.allocate(Optional(parent.copy()), 10)
        var b = runtime.allocate(Optional(parent.copy()), 20)
        runtime.begin(a)
        runtime.arm(a, False, None)
        runtime.begin(b)
        runtime.arm(b, False, None)
        var revision = event.revision()
        event.notify()
        var first = event._subscribe(revision, runtime.waker(a))
        check(runtime.ready(a), "notification before subscription retained")
        var second = event._subscribe(event.revision(), runtime.waker(b))
        for _ in range(8):
            event.notify()
        check(runtime.next_child(parent).value() == 10, "duplicate wake keeps FIFO position")
        var stale_epoch = runtime.waker(a)
        runtime.begin(a)
        runtime.arm(a, False, None)
        check(not stale_epoch.wake(), "old poll epoch cannot wake a later wait")
        check(runtime.next_child(parent).value() == 20, "one queue entry per child")
        _ = first^
        _ = second^
        runtime.begin(b)
        runtime.arm(b, False, Optional(clock.now() + tick))
        # A live early deadline prevents stale later entries from being trimmed
        # from the top. Replacements must exercise heap compaction instead.
        for i in range(96):
            runtime.begin(a)
            runtime.arm(a, False, Optional(clock.now() + Duration.nanoseconds(100 + i)))
            var guard = _lock_metadata(runtime._cell)
            ref state = guard.cell[].slot.value()
            timers_peak = max(timers_peak, len(state.timers))
            check(len(state.timers) <= 2 * state.live_timers + 33, "timer tombstones bounded during rearm")
        check(not runtime.fire_due(clock.now()), "timers cannot fire early")
        clock.advance_to(clock.now() + tick)
        check(runtime.fire_due(clock.now()) and runtime.ready(b), "earliest timer wakes its child")
        var stale_generation = runtime.waker(a)
        runtime.retire(a)
        var reused = runtime.allocate(Optional(parent.copy()), 30)
        check(reused.index == a.index and reused.generation != a.generation, "retired index reused with new generation")
        runtime.begin(reused)
        runtime.arm(reused, False, None)
        check(not stale_generation.wake(), "old generation cannot wake replacement")
        runtime.retire(reused)
        runtime.retire(b)
        check(not runtime.next_deadline() and not runtime.ready(parent), "retirement removes timers and ancestor readiness")
        var guard = _lock_metadata(runtime._cell)
        ref state = guard.cell[].slot.value()
        check(state.active == 1 and state.live_timers == 0 and len(state.timers) == 0, "only persistent parent remains")
        check(len(state.nodes) == 4 and len(state.free) == 2, "registry retains only peak concurrency")
        if cycles == 0:
            node_capacity = state.nodes.capacity()
            free_capacity = state.free.capacity()
        check(state.nodes.capacity() == node_capacity, "node allocation capacity plateaus")
        check(state.free.capacity() == free_capacity, "free slot allocation capacity plateaus")
        _ = guard^
        var subscriptions = _lock_metadata(event._cell)
        ref entries = subscriptions.cell[].slot.value()
        check(entries.active == 0 and len(entries.entries) == 2 and len(entries.free) == 2, "all signal registrations retired and reused")
        if cycles == 0:
            subscription_capacity = entries.entries.capacity()
        check(entries.entries.capacity() == subscription_capacity, "signal allocation capacity plateaus")
        check(entries.free.capacity() == 2, "free subscription storage remains bounded")
        cycles += 1
    runtime.retire(parent)
    var final = _lock_metadata(runtime._cell)
    check(final.cell[].slot.value().active == 0, "persistent parent retired")
    print("stress metadata", "cycles=" + String(cycles), "elapsed_ns=" + String(window.elapsed()),
          "nodes=4", "node_capacity=" + String(node_capacity), "subscriptions=2",
          "subscription_capacity=" + String(subscription_capacity), "timers_peak=" + String(timers_peak),
          "active=0", "live_timers=0", flush=True)
