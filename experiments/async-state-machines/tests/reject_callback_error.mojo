# error: constraint failed
# error: comptime assert _CallbackUnit[Self.C.Value] and Self.C.Error == Self.Error
from std.memory import ArcPointer
from callbacks import Register
from state_machine import Completion, callback, pure, run

def main():
    var unit: NoneType = None
    _ = run(callback(Register(ArcPointer(Optional[Completion[Int, Int]]()), ArcPointer(List[Int]([0, 0])), 1, False), pure[String](unit)))
