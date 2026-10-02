"""Route a queue of commands with guarded clauses, a trace context and a typed failure."""
import fp
from fp.adt import Data, Cases, Node, Value
from fp.data import Result, Ok, Err, attempt
from fp.iteration import map, collect_list
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Job(Copyable):
    var id: Int
    var cost: Int


@fieldwise_init
struct Submit(Copyable):
    var job: Job


@fieldwise_init
struct Retry(Copyable):
    var job: Job


@fieldwise_init
struct Cancel(Copyable):
    var job: Job


struct Command(Data):
    comptime Layer[R: Value] = Cases[Submit, Retry, Cancel]


comptime C = Node[Command]
comptime Trace = ArcPointer[List[String]]


@fieldwise_init
struct DispatchFailure(Movable, Writable):
    var job_id: Int

    def write_to(self, mut writer: Some[Writer]):
        writer.write("dispatch failed for job ", self.job_id)


def allowed(job: Job, trace: Trace) -> Bool:
    trace[].append("check " + String(job.id))
    return job.cost <= 5


def dispatch(job: Job, trace: Trace) raises DispatchFailure -> Int:
    trace[].append("dispatch " + String(job.id))
    if job.id == 3:
        raise DispatchFailure(job.id)
    return job.id


def defer(trace: Trace) -> Int:
    trace[].append("defer")
    return 0


def route(command: C, trace: Trace) raises DispatchFailure -> Int:
    """Dispatch a submitted or retried job its guard allows; defer everything else."""
    return fp.match(command,
        fp.when[lambda (s: Submit, t: Trace) -> Bool: allowed(s.job, t),
                lambda (s: Submit, t: Trace) raises DispatchFailure -> Int: dispatch(s.job, t)],
        fp.when[lambda (r: Retry, t: Trace) -> Bool: allowed(r.job, t),
                lambda (r: Retry, t: Trace) raises DispatchFailure -> Int: dispatch(r.job, t)],
        lambda (c: C, t: Trace) -> Int: defer(t),
        context=trace)


def outcome(result: Result[Int, DispatchFailure]) -> String:
    return fp.match(result,
        lambda (ok: Ok[Int]) -> String: "deferred" if ok.value == 0 else "dispatched " + String(ok.value),
        lambda (err: Err[DispatchFailure]) -> String: String(err.value))


def main() raises:
    var trace = Trace(List[String]())
    var queue: List[C] = [Submit(Job(1, 4)), Retry(Job(2, 6)), Cancel(Job(4, 1)), Submit(Job(3, 5))]

    # A lazy callback cannot raise, so `attempt` keeps each failure as an `Err`.
    def routed(var command: C) {trace} -> String:
        return outcome(attempt(route, command, trace))
    var outcomes = collect_list(map(routed, queue^))

    assert_equal(outcomes, ["dispatched 1", "deferred", "deferred", "dispatch failed for job 3"])
    assert_equal(trace[], ["check 1", "dispatch 1", "check 2", "defer", "defer", "check 3", "dispatch 3"])
    print(String("; ").join(outcomes))
