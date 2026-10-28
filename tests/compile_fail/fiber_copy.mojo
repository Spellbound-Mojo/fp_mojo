# error: copy
from fp.effects import unsafe_start
from fp.effects import delay
def body()->Int:return 1
def main() raises:
    var child=unsafe_start(delay[Error](body))
    _=child.copy()
