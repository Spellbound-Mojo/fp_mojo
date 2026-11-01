from fp._binding_architecture import Capture
from std.testing import assert_equal
def keyword(mut state: Int, var text: String, /, var **options: Int) raises Never:
    state += text.byte_length()
    for entry in options.items(): state += entry.value
def main() raises:
    var state = 1
    assert_equal(Capture[Never].mut_owned_kwargs(keyword).run(state, String("a"), extra=2).is_ok(), True)
    assert_equal(state, 4)
