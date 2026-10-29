# error: 'task' abandoned without being explicitly destroyed
from fp.effects import CancellationToken
from state_machine import Task, Sleep


def main():
    var task = Task(Sleep[Int](0), CancellationToken())
    _ = task.tick()
