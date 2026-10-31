# error: 'make_ref' parameter 'I' has 'Concurrent' type, but value has type 'AnyStruct[SyncIO[Int]]'
from fp.effects import SyncIO, make_ref


def main():
    # The synchronous family has no fibers, so it is not a Concurrent provider.
    _ = make_ref[SyncIO[Int]](1)
