# error: no matching function
from fp.functions import partial
from fp.iteration import filter_map
def select(limit: Int, value: String) -> Optional[Int]: return Optional(value.byte_length() + limit)
def main():
    var project = partial(select, 1)
    _ = filter_map(range(3), project)
