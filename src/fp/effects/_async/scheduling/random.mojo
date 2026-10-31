"""A per-thread pseudo-random source for choosing stripes and victims."""


struct _Random(Movable):
    """Xorshift64* state, owned by one thread like Cats Effect's `ThreadLocalRandom`.

    The sequence only spreads contention; nothing depends on its quality.
    """
    var _state: UInt64

    def __init__(out self, seed: UInt64):
        # Mix the seed with SplitMix64's finalizer so nearby seeds diverge; zero is
        # the one state xorshift never leaves, so it is replaced.
        var z = seed + 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) * 0x94D049BB133111EB
        z = z ^ (z >> 31)
        self._state = z if z != 0 else 0x2545F4914F6CDD1D

    @always_inline
    def next(mut self) -> UInt64:
        var x = self._state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        self._state = x
        return x * 0x2545F4914F6CDD1D

    @always_inline
    def below(mut self, bound: Int) -> Int:
        """A value in `[0, bound)` for a positive `bound` below 2**32."""
        return Int(((self.next() >> 32) * UInt64(bound)) >> 32)
