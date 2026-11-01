"""Public host timing is usable without private runtime APIs."""
from std.time import monotonic, sleep
from std.os import abort

def main():
    var before = monotonic()
    sleep(0.0)
    if monotonic() < before:
        abort("monotonic time moved backwards")
    print("public monotonic clock and timed sleep available")
