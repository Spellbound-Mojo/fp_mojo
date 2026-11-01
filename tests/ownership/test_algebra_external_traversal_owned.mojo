"""External Result bases obey the same move-only traversal contract as native ones."""
from fp.algebra import ResultFamily
from fp.effects import StateT
from test_attempt_once import Token
from test_algebra_traversal_owned import check_traversal_ownership
from algebra_support.external import PublicMonad

def main() raises:
    check_traversal_ownership[StateT[PublicMonad[ResultFamily[Token[3]]],Token[1]]]()
