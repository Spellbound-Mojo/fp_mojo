# error: use of uninitialized value 'project'
from fp.functions import partial
from fp.iteration import sum_by
def add(offset: Int, value: Int) -> Int: return offset + value
def main():
    var project = partial(add, 1)
    _ = sum_by(project^, range(3))
    _ = sum_by(project, range(3))
