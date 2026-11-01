# error: 'start' parameter 'I' has 'Spawn' type, but value has type 'AnyStruct[SyncIO[Int]]'
from fp.effects import SyncIO, delay, start
from fp.callables import OnceThunk


@fieldwise_init
struct One(OnceThunk):
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        return 1


def main():
    _ = start[SyncIO[Int]](delay[SyncIO[Int]](One()))
