# error: violated constraint
from fp.functions import pipeline
def main():
    _ = pipeline(Optional(3)).raise_on_err()
