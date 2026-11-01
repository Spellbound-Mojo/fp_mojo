# error: value passed to 'fd' cannot be converted from 'IntLiteral[3]' to 'RawFileDescriptor'
from fp.effects.async_runtime.protocols import await_readable


def main():
    # Descriptor waits take the standard library's RawFileDescriptor, not a bare Int.
    _ = await_readable[Int](3)
