"""Materialization exposes only recoverable errors as successful Result values."""
from fp.effects._async.kernel import run
from foundation import check
from recovery_support import source


def main():
    for mode in range(4):
        var outcome = run(source(mode).attempt())
        if mode == 1:
            check(not outcome, "attempt must not recover cancellation-only")
        elif mode == 3:
            var failure = outcome.take()._take_err()
            check(failure.canceled and len(failure.errors) == 2, "attempt retains terminal canceled errors")
        else:
            var result = outcome.take()._take_ok()
            if mode == 0:
                check(result^._take_ok() == 42, "attempt wraps success")
            else:
                var failure = result^._take_err()
                check(not failure.canceled and len(failure.errors) == 2, "attempt transfers all noncanceled errors")
    print("attempt: canonical materialization, success, complete errors, cancellation bypass")
