# error: cannot be converted from 'IntLiteral[123]' to 'Instant'
from fp.effects._async.kernel import Wait

def main():
    _ = Wait.until(123)
