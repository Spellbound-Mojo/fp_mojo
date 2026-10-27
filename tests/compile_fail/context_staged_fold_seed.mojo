# error: no matching method
from context_staged_fold_contract_support import forward
from context_fold_contract_support import Add, Once, SumOwned, owned_items
from fp.algebra import OptionalFamily, ListFamily
from fp.functions import pipeline

def main():
    _ = pipeline(List[Int]([1])).fold_effect[OptionalFamily](String()).run(Add[OptionalFamily]())
