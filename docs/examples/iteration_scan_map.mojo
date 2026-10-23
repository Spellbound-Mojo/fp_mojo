"""A move-only running state with independent text outputs."""
from fp.iteration import iterated


@fieldwise_init
struct RunningTotal(Movable):
    var value: Int


def main():
    var calls=0
    @always_inline
    def step(var carry: RunningTotal,var item: Int) {mut calls}->Tuple[RunningTotal,String]:
        calls+=1
        carry.value+=item
        var text="total="+String(carry.value)
        return (carry^,text^)
    var values=iterated(range(1,5)).scan_map(step,RunningTotal(0))
    print("before consuming:",calls)
    print(values^.take(3).to_list())
    print("steps:",calls)
    print("empty:",iterated(range(0)).scan_map(step,RunningTotal(0)).to_list())
    print("steps after empty:",calls)
