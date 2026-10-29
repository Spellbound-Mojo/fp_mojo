# error: no matching function in initialization
from fp.effects._async.kernel import Step, Wait


def main():
    _ = Step[Int, Int](None, Wait(), True)
