# error: violated constraint
from fp.functions import pipeline
def main():
    _ = pipeline(Optional(1)).swap()
