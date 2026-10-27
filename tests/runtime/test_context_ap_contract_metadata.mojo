from context_ap_contract_support import Plus, Consuming, Missing, KeepMove, CopyOnce, MoveState
from fp.algebra import ApContract, OptionalFamily, ListFamily

def main():
    comptime assert not ApContract[OptionalFamily,Optional[Int],Optional[Int]].CallableCompatible
    comptime assert not ApContract[OptionalFamily,Optional[Int],Optional[Int]].Compatible
    comptime assert ApContract[OptionalFamily,Optional[Missing],Optional[Int]].ShapeCompatible
    comptime assert not ApContract[OptionalFamily,Optional[Missing],Optional[Int]].ReceiverCompatible
    comptime assert not ApContract[OptionalFamily,Optional[Missing],Optional[Int]].Compatible
    comptime assert ApContract[OptionalFamily,Optional[Consuming],Optional[Int]].Compatible
    comptime assert ApContract[ListFamily,List[CopyOnce],List[Int]].Compatible
    comptime assert not ApContract[ListFamily,List[Consuming],List[Int]].Compatible
    comptime assert not ApContract[ListFamily,List[KeepMove],List[MoveState]].Compatible
    comptime assert not ApContract[OptionalFamily,Optional[Plus],Optional[String]].InputCompatible
