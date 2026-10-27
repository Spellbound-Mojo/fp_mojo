# error: no matching method in call to 'if_effect'
from context_if_contract_support import Once, ErrorFactory
from fp.algebra import OptionalFamily, ListFamily
from fp.functions import pipeline
def main(): _ = pipeline(Optional(True)).if_effect(ErrorFactory[Int](), ErrorFactory[String]()).get()
