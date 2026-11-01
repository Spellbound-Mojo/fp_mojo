# error: use of uninitialized value 'callback'
from fp.callables import shared_ref,SharedRef
from shared_ref_support import Callback
from fp.iteration import iterated
def main():
    var callback=Callback(1)
    var pending=iterated(range(3)).map(shared_ref(callback))
    var moved=callback^
    print(moved.offset)
    print(pending^.to_list())
