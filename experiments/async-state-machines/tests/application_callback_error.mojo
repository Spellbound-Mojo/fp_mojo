# error: call to 'callback'
from fp.effects._async.application import callback, Completion, pure


def wrong(var completion: Completion[Int, Int]) raises String:
    raise String("not the selected error")


def main():
    _ = callback(wrong, pure[Int](NoneType()))
