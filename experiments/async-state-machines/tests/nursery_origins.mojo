"""Dynamic storage and submission handles preserve concrete external origins."""
from fp.effects import Outcome
from state_machine import Nursery, Spawner, run
from foundation import Borrowed, check


def borrowed_group[o: ImmOrigin](ref[o] owner: List[Int], fail: Bool) -> Outcome[List[Span[Int, o]], Span[Int, o]]:
    var nursery = Nursery[Borrowed[o]](2)
    var spawn = nursery.spawner()
    check(not spawn.try_spawn(Borrowed(Pointer(to=owner), 0, fail)), "borrowed child accepted")
    spawn.close()
    return run(nursery^)


def retained[o: ImmOrigin](ref[o] owner: List[Int]) -> Spawner[Borrowed[o]]:
    var nursery = Nursery[Borrowed[o]](1)
    var spawn = nursery.spawner()
    check(not spawn.try_spawn(Borrowed(Pointer(to=owner), 0, False)), "borrowed recipe queued")
    _ = nursery^
    return spawn^


def main():
    var owner = List[Int]([13, 17])
    var success = borrowed_group(owner, False)
    var values = success.take()._take_ok()
    check(values[0][1] == 17, "dynamic result retains owner origin")
    var failed = borrowed_group(owner, True)
    var error = failed.take()._take_err()
    check(error.errors.first()[0] == 13, "dynamic error retains owner origin")
    _ = retained(owner)
    print("nursery origins: borrowed recipes, results, errors and retained submission handles")
