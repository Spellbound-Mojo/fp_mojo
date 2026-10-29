"""Compile-only capability probe for host atomic waiting."""
from std.atomic import Atomic

def main():
    var flag = Atomic(UInt8(0))
    flag.wait(UInt8(0))
