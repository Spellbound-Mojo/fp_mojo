# error: invalid call to 'chain'
from fp.iteration import iterated
def main():
    var words: List[String] = ["a"]
    _ = iterated(range(3)).chain(words^)
