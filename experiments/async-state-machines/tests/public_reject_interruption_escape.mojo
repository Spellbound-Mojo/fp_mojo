# error: value of type 'Interruption' cannot be implicitly copied, it does not conform to 'ImplicitlyCopyable'
from fp.effects.async_runtime import IO, Interruption


def keep(handle: Interruption) -> Interruption:
    # The handle lives only for the call: it can be neither copied nor moved out.
    return handle


def main():
    _ = IO[Interruption, Int].interruptible(keep)
