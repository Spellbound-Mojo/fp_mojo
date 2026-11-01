# error: copy
from fp.effects import Semaphore
from fp.effects import run_io
def main() raises:
    var sem=Semaphore(1)
    var outcome=run_io(sem.acquire[Error]())
    var result=outcome.take()
    var permit=result^._take_ok()
    _=permit.copy()
