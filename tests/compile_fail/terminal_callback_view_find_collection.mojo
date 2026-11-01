# error: no matching method in call to 'find_map'
from fp.functions import partial, pipeline
def collect(offset: Int, value: Int) -> List[Int]: return List[Int]([offset + value])
def main():
    var project = partial(collect, 1)
    _ = pipeline(List[Int]([1, 2])).find_map(project).get()
