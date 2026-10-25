# error: failed to infer parameter 'K'
from fp.data import Capture

def callback(mut state: Int, var text: String, /, var **options: Int) -> Int:
    return state

def main():
    var state = 0
    _ = Capture[Never].mutable(state).take("a").kwargs().run(callback)
