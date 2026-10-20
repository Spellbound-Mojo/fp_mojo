# error: use of uninitialized value 'callback'
from fp.iteration import iterated

def main():
    var text = String("an owned string that exceeds the inline storage capacity")
    def callback(var value: Int) {var text^} -> Int:
        return value + text.byte_length()
    _ = iterated(range(3)).map(callback^)
    _ = iterated(range(3)).map(callback^)
