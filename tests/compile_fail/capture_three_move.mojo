# error: uninitialized
from fp.data import Capture

def callback(text: String, mut count: Int, var message: String) -> Int: return text.byte_length()

def main():
    var owner = String("read")
    var state = 0
    var bound = Capture().borrow(owner).mutable(state).take(String("owned"))
    var moved = owner^
    print(moved)
    _ = bound^.run(callback)
