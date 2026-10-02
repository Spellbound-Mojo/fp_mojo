"""Traversal requires only public Applicative operations, including short circuit."""
from fp.algebra import ListFamily
from algebra_support.applicative_traversal import check_traversal


def main() raises:
    check_traversal[ListFamily]()
    print("Applicative-only traversal: empty, success, stored/native failures, exact pulls")
