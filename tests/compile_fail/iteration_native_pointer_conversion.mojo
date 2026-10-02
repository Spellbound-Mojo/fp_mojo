# error: function type conversions between closures not supported yet
"""Native generic runtime-pointer forwarding probe; no fp dependency."""
def forward[T: Movable & Deinitable, U: Movable & Deinitable](
    function: def(var T) thin -> U, var value: T
) -> U:
    return function(value^)

def twice(var value: Int) -> Int:
    return value * 2

def main():
    var callback: def(var Int) thin -> Int = twice
    print(forward(callback, 2))
