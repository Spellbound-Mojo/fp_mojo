# error: no matching
from fp.functions import pipeline
def callback(value: Int) -> Optional[Bool]: return Optional(True)
def main() raises:
    _ = pipeline(3).any_effect(callback)
