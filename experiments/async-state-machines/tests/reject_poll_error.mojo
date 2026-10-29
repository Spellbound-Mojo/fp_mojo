# error: poll requires the same exact error type
from fp.effects import IOContext, CancellationToken
from fp.effects.finalization import Poll as SyncPoll
from state_machine import Poll, pure
def main():
    var context = IOContext[Int](CancellationToken(), False)
    var masked = context._mask()
    var poll = Poll(SyncPoll(context.copy(), masked._region.value().copy()))
    _ = poll.apply(pure[String](1))
