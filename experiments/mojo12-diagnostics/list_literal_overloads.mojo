# Mojo 1.2.0 rejects a bare literal when List and generic-value overloads coexist.
# No FP import is needed; an explicit element binding supplies List context.

def select[T: Movable & Deinitable](var value: List[T]) -> Int:
    return len(value)
def select[V: Movable & Deinitable](var value: V) -> Int:
    _ = value^
    return 0
def main():
    print(select([1, 2]))
