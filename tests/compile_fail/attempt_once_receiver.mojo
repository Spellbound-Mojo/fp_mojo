# error: ThunkContract
from fp.functions import Identity
from fp.data import attempt_once


def main():
    _ = attempt_once(Identity[Int]())
