from context_if_contract_support import Missing, Once, Factory, legacy_selected, expanded_forward, checked_forward
from fp.algebra import IfContract, OptionalFamily
from std.testing import assert_equal

def main() raises:
    comptime Valid = Once[OptionalFamily]
    comptime assert IfContract[OptionalFamily,Optional[Bool],Missing,Valid].Compatible
    comptime assert not IfContract[OptionalFamily,Optional[Bool],Missing,Valid].ReceiverCompatible
    comptime assert not IfContract[OptionalFamily,Optional[Bool],Missing,Valid].InvocationCompatible
    comptime assert not IfContract[OptionalFamily,Optional[Bool],Valid,Missing].InvocationCompatible
    comptime assert IfContract[OptionalFamily,Optional[Bool],Valid,Factory[OptionalFamily]].Compatible
    assert_equal(legacy_selected[OptionalFamily](Valid(1),Valid(2),Optional(True)).value(),1)
    assert_equal(legacy_selected[OptionalFamily](Factory[OptionalFamily](1),Factory[OptionalFamily](2),Optional(False)).value(),2)
    assert_equal(expanded_forward[OptionalFamily](Valid(1),Valid(2),Optional(True)).value(),1)
    assert_equal(checked_forward[OptionalFamily](Valid(1),Valid(2),Optional(False)).value(),2)
