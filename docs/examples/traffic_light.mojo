"""Matching several values together: a light's next state for an event, and a third plain value."""
import fp
from fp.adt import Data, Cases, Node, Value


@fieldwise_init
struct Red(Copyable):
    pass


@fieldwise_init
struct Green(Copyable):
    pass


@fieldwise_init
struct Amber(Copyable):
    pass


struct Light(Data):
    comptime Layer[R: Value] = Cases[Red, Green, Amber]


@fieldwise_init
struct Tick(Copyable):
    pass


@fieldwise_init
struct Outage(Copyable):
    var code: Int


struct Event(Data):
    comptime Layer[R: Value] = Cases[Tick, Outage]


comptime L = Node[Light]
comptime V = Node[Event]


def step(light: L, event: V) -> L:
    return fp.match((light, event),
        lambda (s: Red, e: Tick) -> L: Green(),
        lambda (s: Green, e: Tick) -> L: Amber(),
        lambda (s: Amber, e: Tick) -> L: Red(),
        lambda (s: L, e: Outage) -> L: Red())


def name(light: L) -> String:
    return fp.match(light,
        lambda (r: Red) -> String: "red",
        lambda (g: Green) -> String: "green",
        lambda (a: Amber) -> String: "amber")


def report(light: L, event: V, waiting: Int) -> String:
    """A plain third value takes part in guards like the others."""
    return fp.match((light, event, waiting),
        fp.when[lambda (s: Red, e: Tick, n: Int) -> Bool: n > 3,
                lambda (s: Red, e: Tick, n: Int) -> String: "red with a queue of " + String(n)],
        lambda (s: L, e: Outage, n: Int) -> String: "outage " + String(e.code),
        lambda (s: L, e: V, n: Int) -> String: "normal")


def main():
    var light: L = Red()
    var tick: V = Tick()
    for _ in range(4):
        light = step(light, tick)
        print(name(light))
    print(name(step(light, V(Outage(7)))))
    print(report(L(Red()), tick, 5), "|", report(light, V(Outage(7)), 0), "|", report(light, tick, 0))
