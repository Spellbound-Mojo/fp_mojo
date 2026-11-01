"""No-value and literal Never thin factories use their exact native signatures."""
from fp.functions import pipeline

def action(): pass
def never() raises Never: pass
def main():
    var left:def() thin=action
    var right:def() raises Never thin=never
    _ = pipeline(True).if_effect(left,right).get()
    _ = pipeline(False).if_effect(left,right).get()
