# error: cannot be converted from 'IntLiteral[123]' to 'Instant'
from fp.effects.async_runtime.protocols import Wait

def main():
    _ = Wait.until(123)
