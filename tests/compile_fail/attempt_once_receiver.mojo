# error: no matching method in call to 'run'
from fp.functions import Identity
from fp.data import Capture


def main():
    _ = Capture().run(Identity[Int]())
