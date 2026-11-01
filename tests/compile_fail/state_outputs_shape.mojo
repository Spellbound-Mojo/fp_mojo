# error: violated constraint
from fp.effects import State, StateAction, run_state
@fieldwise_init
struct Bad(StateAction):
    comptime Family = State[Int]
    comptime State = Int
    comptime Value = Int
    comptime Out = String
    def run(deinit self,var state: Int) -> String: return String(state)
def main(): _ = run_state[State[Int]](Bad(),0)
