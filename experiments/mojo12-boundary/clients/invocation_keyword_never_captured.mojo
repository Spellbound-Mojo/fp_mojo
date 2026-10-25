from fp._binding_staged import KeywordCall
from std.testing import assert_equal
def main() raises:
    var calls=0
    def callback(mut state:Int,var text:String,/,var **options:Int) raises Never {mut calls}:
        calls+=1
        state+=text.byte_length()
        for item in options.items():state+=item.value
    var adapter=KeywordCall[Int,String,Int,Never].of(callback)
    var state=0
    assert_equal(adapter.run(state,String("a"),extra=1).is_ok(),True)
    assert_equal(calls,1)
    assert_equal(state,2)
