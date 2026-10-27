"""Combination contracts expose copy, receiver and native-error prerequisites."""
from fp.algebra import CombineContract, ListFamily, ResultFamily
from fp.effects import OptionalT, ResultT, Reader
from fp.callables._transforms import _ValueThunk
from context_combination_admission_support import AdmissionBase,MoveState,MoveLeft,MoveRight,Add,OnceAdd,CapturedAdd,Missing,ErrorAdd,OtherError

def main():
    comptime assert not CombineContract[ListFamily,List[MoveState],MoveLeft,_ValueThunk[List[Int]]].Compatible
    comptime assert not CombineContract[ListFamily,List[Int],MoveRight,_ValueThunk[List[MoveState]]].Compatible
    comptime assert not CombineContract[ListFamily,List[Int],OnceAdd,_ValueThunk[List[Int]]].Compatible
    comptime assert not CombineContract[ListFamily,List[Int],Add,Missing].Compatible
    comptime assert not CombineContract[ListFamily,List[Int],ErrorAdd,OtherError].Compatible
    comptime O=OptionalT[ListFamily]
    comptime R=ResultT[ListFamily,String]
    comptime assert not CombineContract[O,O.Pure[Int],OnceAdd,_ValueThunk[O.Pure[Int]]].Compatible
    comptime assert not CombineContract[R,R.Pure[Int],OnceAdd,_ValueThunk[R.Pure[Int]]].Compatible
    comptime assert not CombineContract[O,O.Pure[MoveState],MoveLeft,_ValueThunk[O.Pure[Int]]].Compatible
    comptime assert not CombineContract[R,R.Pure[MoveState],MoveLeft,_ValueThunk[R.Pure[Int]]].Compatible
    comptime assert not CombineContract[O,O.Pure[Int],CapturedAdd,_ValueThunk[O.Pure[Int]]].Compatible
    comptime assert not CombineContract[R,R.Pure[Int],CapturedAdd,_ValueThunk[R.Pure[Int]]].Compatible
    comptime B=OptionalT[AdmissionBase[ResultFamily[String],False]]
    comptime assert not CombineContract[B,B.Pure[Int],Add,_ValueThunk[B.Pure[Int]]].Compatible
    comptime Single=ResultT[Reader[Int],String]
    comptime assert CombineContract[Single,Single.Pure[Int],OnceAdd,_ValueThunk[Single.Pure[Int]]].Compatible
