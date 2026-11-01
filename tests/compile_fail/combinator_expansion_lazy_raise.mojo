# error: no matching method in call to 'pair_with'
from fp.iteration import iterated
def expansion_project(x: Int) raises -> Int: return x
def main():
    _ = iterated(range(3)).pair_with(expansion_project)
