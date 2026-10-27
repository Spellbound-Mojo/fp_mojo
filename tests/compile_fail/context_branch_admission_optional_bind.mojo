# error: no matching method in call to 'flat_map'
"""Declared primitive admission rejects the callback before family execution."""
from fp.algebra import ListFamily,ResultFamily,ApplicativeError
from fp.effects import OptionalT,ResultT,StateT,action
from fp.functions import pipeline
from std.builtin.rebind import downcast
from context_branch_admission_support import OnceMap,StatefulMap,OnceNext,OnceRecovery,OnceValue,OnceObserver,MoveState,FailedBranches

def main():
    comptime I=OptionalT[ListFamily]
    _=pipeline[I](I.pure(1)).flat_map(OnceNext[I]())
