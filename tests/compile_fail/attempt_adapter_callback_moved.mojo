# error: use of uninitialized value 'callback'
from fp.data import attempt
from fp.data import mutating

def main():
    var anchor = String("kept")
    def callback(mut value: Int) {var anchor^} -> Int:
        value += anchor.byte_length()
        return value
    var view = mutating(callback)
    var moved = callback^
    var value = 3
    _ = attempt(view, value)
    _ = moved(value)
