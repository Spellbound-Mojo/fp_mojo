# error: copy constructor must not declare 'raises'
# Mojo Copyable constructors cannot introduce a throwing-copy channel.
@fieldwise_init
struct ThrowingCopy(Copyable):
    var value: Int
    def __init__(out self, *, copy: Self) raises Error:
        raise Error('copy failed')
def main():
    var value = ThrowingCopy(1)
    _ = value.copy()
