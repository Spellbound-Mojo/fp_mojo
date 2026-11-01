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


struct SystemTime(Copyable, Comparable, Writable):
    """A wall-clock timestamp: signed nanoseconds since the Unix epoch, in UTC.

    A wall clock can be set, so readings can move backward; elapsed time
    belongs to the monotonic clock and its Instant. A SystemTime is never an
    Instant, and the two never convert. The signed nanosecond count covers
    roughly the years 1677 through 2262. `SystemTime()` is the epoch.
    """
    var _nanoseconds: Int

    def __init__(out self):
        """Create the Unix epoch, 1970-01-01T00:00:00Z."""
        self._nanoseconds = 0

    @staticmethod
    def nanoseconds(value: Int) -> Self:
        """Store a signed nanosecond count since the epoch; every Int is valid.

        Args:
            value: Nanoseconds since the epoch, negative before it.

        Returns:
            The timestamp.
        """
        var time = Self()
        time._nanoseconds = value
        return time^

    @staticmethod
    def seconds(value: Int) raises -> Self:
        """Check a signed second count since the epoch before converting it.

        Args:
            value: Seconds since the epoch, negative before it.

        Returns:
            The timestamp, with exact integer conversion.

        Raises:
            Error: A count whose nanoseconds overflow Int.
        """
        comptime scale = 1000000000
        if value > Int.MAX // scale or value < Int.MIN // scale:
            raise Error("system time outside supported range")
        return Self.nanoseconds(value * scale)

    def to_nanoseconds(self) -> Int:
        """Read the timestamp as signed nanoseconds since the epoch.

        Returns:
            The nanosecond count, negative before the epoch.
        """
        return self._nanoseconds

    def to_seconds(self) -> Int:
        """Read the timestamp as whole seconds since the epoch, rounding down.

        Returns:
            The floor of the second count, so one nanosecond before the
            epoch reads as -1.
        """
        return self._nanoseconds // 1000000000

    def since(self, earlier: Self) -> Optional[Duration]:
        """Measure the duration from an earlier timestamp.

        Unlike Instant.since, which reads zero for a later argument, this
        reports it: an Instant never goes backward, but the wall clock can be
        set back between two readings, as Rust's SystemTime.duration_since
        reports. Measure elapsed time with the monotonic clock instead.

        Args:
            earlier: A timestamp, normally read before this one.

        Returns:
            The elapsed duration, saturating at the largest supported duration,
            10**18 nanoseconds; None if `earlier` is later than this timestamp.
        """
        if earlier > self:
            return None
        comptime limit = Duration._maximum_nanoseconds
        var elapsed = Duration()
        if self._nanoseconds >= 0 and earlier._nanoseconds < 0 and (self._nanoseconds > limit or earlier._nanoseconds < -limit):
            elapsed._nanoseconds = limit
        else:
            # Same signs cannot overflow; mixed signs here are each within the limit.
            elapsed._nanoseconds = min(self._nanoseconds - earlier._nanoseconds, limit)
        return Optional(elapsed^)

    def after(self, duration: Duration) raises -> Self:
        """Compute a later timestamp.

        Args:
            duration: The nonnegative duration to add.

        Returns:
            The later timestamp; the original remains unchanged.

        Raises:
            Error: The result lies past the supported range.
        """
        if self._nanoseconds > Int.MAX - duration._nanoseconds:
            raise Error("system time outside supported range")
        return Self.nanoseconds(self._nanoseconds + duration._nanoseconds)

    def before(self, duration: Duration) raises -> Self:
        """Compute an earlier timestamp.

        Args:
            duration: The nonnegative duration to subtract.

        Returns:
            The earlier timestamp; the original remains unchanged.

        Raises:
            Error: The result lies before the supported range.
        """
        if self._nanoseconds < Int.MIN + duration._nanoseconds:
            raise Error("system time outside supported range")
        return Self.nanoseconds(self._nanoseconds - duration._nanoseconds)

    def __add__(self, duration: Duration) raises -> Self:
        """Add a duration through the same arithmetic owner as after."""
        return self.after(duration)

    def __sub__(self, duration: Duration) raises -> Self:
        """Subtract a duration through the same arithmetic owner as before."""
        return self.before(duration)

    def __lt__(self, other: Self) -> Bool:
        return self._nanoseconds < other._nanoseconds
    def __eq__(self, other: Self) -> Bool:
        return self._nanoseconds == other._nanoseconds
    def __ne__(self, other: Self) -> Bool:
        return self._nanoseconds != other._nanoseconds
    def __le__(self, other: Self) -> Bool:
        return self._nanoseconds <= other._nanoseconds
    def __gt__(self, other: Self) -> Bool:
        return self._nanoseconds > other._nanoseconds
    def __ge__(self, other: Self) -> Bool:
        return self._nanoseconds >= other._nanoseconds

    def write_to(self, mut writer: Some[Writer]):
        """Write RFC 3339 UTC, such as 2023-11-14T22:13:20Z.

        Nine fractional digits follow the seconds only when the sub-second
        part is nonzero. Times before the epoch use the proleptic Gregorian
        calendar.

        Args:
            writer: The destination.
        """
        comptime day = 86400
        var seconds = self.to_seconds()
        var fraction = self._nanoseconds - seconds * 1000000000
        var days = seconds // day
        var of_day = seconds - days * day
        # Howard Hinnant's civil_from_days; Int's // already floors.
        var z = days + 719468
        var era = z // 146097
        var doe = z - era * 146097
        var yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
        var doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
        var mp = (5 * doy + 2) // 153
        var month = mp + 3 if mp < 10 else mp - 9
        var year = yoe + era * 400 + (1 if month <= 2 else 0)
        _write_padded(writer, year, 4)
        writer.write("-")
        _write_padded(writer, month, 2)
        writer.write("-")
        _write_padded(writer, doy - (153 * mp + 2) // 5 + 1, 2)
        writer.write("T")
        _write_padded(writer, of_day // 3600, 2)
        writer.write(":")
        _write_padded(writer, of_day // 60 % 60, 2)
        writer.write(":")
        _write_padded(writer, of_day % 60, 2)
        if fraction != 0:
            writer.write(".")
            _write_padded(writer, fraction, 9)
        writer.write("Z")


def _write_padded(mut writer: Some[Writer], value: Int, width: Int):
    """Write a nonnegative value with leading zeros to at least width digits."""
    var digits = String(value)
    for _ in range(width - digits.byte_length()):
        writer.write("0")
    writer.write(digits)
