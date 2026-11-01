# error: no matching method in call to 'flat_map'
from fp.functions import pipeline_values, Identity

def main():
    var values = Dict[String, Int]()
    _ = pipeline_values(values^).flat_map(Identity[Int]())
