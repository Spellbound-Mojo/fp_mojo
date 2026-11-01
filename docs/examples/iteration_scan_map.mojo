"""A move-only running state with independent text outputs."""
from fp.iteration import iterated
from fp.functions import partial


@fieldwise_init
struct RunningTotal(Movable):
    var value: Int


def priced(scale: Int, total: Int, quantity: Int) -> Tuple[Int, Int]:
    var next_total = total + scale * quantity
    return (next_total, next_total)


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
    var price = partial(priced, 3)
    print("prices:", iterated(range(1,4)).scan_map(price, 0).collect_list())
    print("reused:", iterated(range(1,3)).scan_map(price, 10).collect_list())
    var accumulated = iterated(range(1,4)).map_accumulate(price, 0)
    print("final total:", accumulated[0])
    print("collected:", accumulated[1])
    print("moved:", iterated(range(1,3)).scan_map(price^, 0).collect_list())
