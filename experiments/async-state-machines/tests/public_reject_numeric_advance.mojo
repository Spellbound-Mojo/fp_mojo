# error: cannot be converted from 'IntLiteral[123]' to 'Instant'
from fp.effects.async_runtime import Clock

def main() raises:
    var clock = Clock.manual()
    clock.advance_to(123)
