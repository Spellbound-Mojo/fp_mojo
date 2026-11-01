# error: invalid call to 'attempt': violated constraint
from fp.functions import pipeline

def main():
    _ = pipeline(Optional(42)).attempt().get()
