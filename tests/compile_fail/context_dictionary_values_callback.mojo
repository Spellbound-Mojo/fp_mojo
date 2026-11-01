# error: no matching method in call to 'map'
from fp.functions import pipeline_values, Identity

def main():
    var values = Dict[String, Int]()
    _ = pipeline_values(values^).map(Identity[String]())
