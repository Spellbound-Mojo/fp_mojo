# error: constraint failed: cede: mismatched base family, or a layer whose programs are not base programs
from fp.effects import StateT, LiftSpawn, cede
from fp.effects.async_runtime import Async


def main():
    # StateT forwards only Defer and Raise.
    _ = cede[LiftSpawn[StateT[Async[Int], Int], Async[Int]]]()
