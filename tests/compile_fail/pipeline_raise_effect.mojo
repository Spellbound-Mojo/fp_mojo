# error: cannot call function that may raise in a context that cannot raise
from fp.data import err
from fp.functions import pipeline
def main():
    _ = pipeline(err[Int]("bad")).raise_on_err()
