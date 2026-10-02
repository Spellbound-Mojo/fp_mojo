"""Run the shared calculation without MAX or a GPU; this is a host control."""
from core import core, expected
from std.testing import assert_equal

def main() raises:
    for x in range(-32, 33):
        assert_equal(core(x), expected(x))
    print('device core host control: ok')
