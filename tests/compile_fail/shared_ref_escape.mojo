# error: cannot implicitly convert 'SharedRef[Callback, origin_of(local)]'
from fp.callables import shared_ref,SharedRef
from shared_ref_support import Callback
def wrong[o:ImmOrigin](ref[o] owner:Callback)->SharedRef[Callback,o]:
    var local=Callback(1)
    return shared_ref(local)
def main():
    var callback=Callback(0)
    _=wrong(callback)
