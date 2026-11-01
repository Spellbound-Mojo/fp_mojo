# Mojo 1.2.0 rejects bare function promotion through these generic read traits.
# No FP import is needed. Selected Pipeline.fold calls admit this function directly.
from std.testing import assert_equal

def never(value: Int) raises Never -> Int: return value + 1
def forward[T: Movable & Deinitable, E: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(T) raises X -> R, G: def(E) raises X -> R](value: T, error: E, on_ok: F, on_err: G) raises X -> R:
    _ = on_ok(value)
    return on_err(error)
def main() raises:
    assert_equal(forward(4, 4, never, never), 5)
