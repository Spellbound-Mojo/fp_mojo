# error: use of uninitialized value 'project'
from fp.functions import partial
from fp.iteration import iterated
def select(offset: Int, value: Int) -> Optional[Int]: return Optional(offset + value)
def main():
    var project = partial(select, 1)
    var pending = iterated(range(3)).filter_map(project)
    var moved = project^
    _ = moved(0)
    _ = pending^.collect_list()
