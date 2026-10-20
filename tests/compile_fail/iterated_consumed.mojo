# error: use of uninitialized value 'stream'
from fp.iteration import iterated

def main():
    var stream = iterated(range(3))
    _ = stream^.collect_list()
    _ = stream^.to_list()
