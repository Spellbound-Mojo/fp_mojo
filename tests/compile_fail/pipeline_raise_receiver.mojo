# error: invalid call to 'raise_on_err': failed to infer parameter
from fp.functions import pipeline
def main():
    _ = pipeline(Optional(3)).raise_on_err()
