"""Checked relative durations and opaque absolute time for host scheduling."""
from std.os import abort


struct Duration(Copyable):
    """A checked nonnegative relative duration, stored in integer nanoseconds.

    Conversion admits at most 10**18 nanoseconds, preserving the experimental
    timer range. Absolute deadlines use Instant arithmetic without narrowing to Int.
    """
    comptime _maximum_nanoseconds = 1000000000000000000
    var _nanoseconds: Int

    def __init__(out self):
        """Create a zero duration."""
        self._nanoseconds = 0

    @staticmethod
    def _valid_scaled[scale: Int](value: Int) -> Bool:
        comptime assert scale > 0
        return 0 <= value <= Self._maximum_nanoseconds // scale

    @staticmethod
    def _from_scaled[scale: Int](value: Int) raises -> Self:
        if not Self._valid_scaled[scale](value):
            raise Error("duration outside supported range")
        var result = Self()
        result._nanoseconds = value * scale
        return result^

    @staticmethod
    def nanoseconds(value: Int) raises -> Self:
        """Check and store an integer nanosecond count.

        Args:
            value: A count from zero through 10**18 inclusive.

        Returns:
            A checked relative duration.

        Raises:
            Error: A negative or out-of-range count, before multiplication.
        """
        return Self._from_scaled[1](value)

    @staticmethod
    def milliseconds(value: Int) raises -> Self:
        """Check an integer millisecond count before converting to nanoseconds.

        Args:
            value: A count from zero through 10**12 inclusive.

        Returns:
            A checked relative duration with exact integer conversion.

        Raises:
            Error: A negative count or one exceeding the supported duration.
        """
        return Self._from_scaled[1000000](value)

    @staticmethod
    def seconds(value: Int) raises -> Self:
        """Check an integer second count before converting to nanoseconds.

        Args:
            value: A count from zero through 10**9 inclusive.

        Returns:
            A checked relative duration with exact integer conversion.

        Raises:
            Error: A negative count or one exceeding the supported duration.
        """
        return Self._from_scaled[1000000000](value)

    def to_nanoseconds(self) -> Int:
        """Read the duration as an integer nanosecond count.

        Returns:
            A count from zero through 10**18 inclusive.
        """
        return self._nanoseconds


struct Instant(Copyable, Comparable):
    """An opaque absolute point in a runtime clock's monotonic origin.

    Compare points only within a shared clock origin. Add checked Duration
    values with after or the addition operator. The private two-word counter
    permits ordinary timer arithmetic across Int.MAX and the low-word boundary;
    it does not expose arbitrary numeric construction or a wall-clock timestamp.
    Counter exhaustion, like wake-generation exhaustion, ends the runtime's
    finite operational lifetime; ordinary bounded configuration cannot approach
    its 128-bit horizon in one operation.
    """
    var _high: UInt64
    var _low: UInt64

    def __init__(out self):
        """Create the zero point in a clock's origin."""
        self._high = 0
        self._low = 0

    @staticmethod
    def _make(high: UInt64, low: UInt64) -> Self:
        var point = Self()
        point._high = high
        point._low = low
        return point^

    @staticmethod
    def _from_ticks(ticks: UInt64) -> Self:
        return Self._make(0, ticks)

    def _after_nanoseconds(self, nanoseconds: Int) -> Self:
        # Callers use Duration's checked range or the same predicate in the
        # experimental Sleep constructor. No callback or domain error is involved.
        var delta = UInt64(nanoseconds)
        var high = self._high
        var low = self._low
        if delta > UInt64.MAX - low:
            if high == UInt64.MAX:
                abort("instant counter exhausted")
            high += 1
            low = delta - (UInt64.MAX - low) - 1
        else:
            low += delta
        return Self._make(high, low)

    def after(self, duration: Duration) -> Self:
        """Compute a later point using checked relative time without narrowing.

        Args:
            duration: The nonnegative relative duration to add.

        Returns:
            A point in the same clock origin; the original remains unchanged.
        """
        return self._after_nanoseconds(duration._nanoseconds)

    def __add__(self, duration: Duration) -> Self:
        """Add a checked duration through the same arithmetic owner as after."""
        return self.after(duration)

    def since(self, earlier: Self) -> Duration:
        """Measure the duration from an earlier point in the same clock origin.

        Args:
            earlier: A point read from the same clock, at most this one.

        Returns:
            The elapsed duration; zero if `earlier` is later, and the largest
            supported duration, 10**18 nanoseconds, if the gap exceeds it.
        """
        var elapsed = Duration()
        if not earlier < self:
            return elapsed^
        var limit = UInt64(Duration._maximum_nanoseconds)
        var high = self._high - earlier._high
        var low: UInt64
        if self._low >= earlier._low:
            low = self._low - earlier._low
        else:
            # Borrow from the high word, which is at least one here.
            high -= 1
            low = (UInt64.MAX - earlier._low) + self._low + 1
        if high > 0 or low > limit:
            elapsed._nanoseconds = Duration._maximum_nanoseconds
        else:
            elapsed._nanoseconds = Int(low)
        return elapsed^

    def __lt__(self, other: Self) -> Bool:
        return self._high < other._high or (self._high == other._high and self._low < other._low)
    def __eq__(self, other: Self) -> Bool:
        return self._high == other._high and self._low == other._low
    def __ne__(self, other: Self) -> Bool:
        return not self == other
    def __le__(self, other: Self) -> Bool:
        return not other < self
    def __gt__(self, other: Self) -> Bool:
        return other < self
    def __ge__(self, other: Self) -> Bool:
        return not self < other
