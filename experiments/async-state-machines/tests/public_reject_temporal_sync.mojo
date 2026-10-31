# error: 'sleep' parameter 'I' has 'Temporal' type, but value has type 'AnyStruct[SyncIO[Int]]'
from fp.effects import SyncIO, sleep
from fp.effects.async_runtime import Duration


def main() raises:
    # A blocking synchronous sleep is not a suspension, so SyncIO is not Temporal.
    _ = sleep[SyncIO[Int]](Duration.milliseconds(1))
