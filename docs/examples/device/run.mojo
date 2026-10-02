"""Explicit GPU launch and transfers around unchanged public FP operations."""
from max.gpu import global_idx
from max.gpu.host import DeviceContext
from layout import TileTensor, row_major
from std.testing import assert_equal
from core import core, expected, Width

comptime Count = 65
comptime InputLayout = row_major[Count]()
comptime OutputLayout = row_major[Count, Width]()


def kernel(
    inputs: TileTensor[DType.int64, type_of(InputLayout), MutAnyOrigin],
    outputs: TileTensor[DType.int64, type_of(OutputLayout), MutAnyOrigin],
):
    # This assertion prevents a host-target build from serving as GPU evidence.
    from std.sys.info import is_gpu
    comptime assert is_gpu(), 'The kernel must compile for an accelerator'
    comptime assert inputs.flat_rank == 1 and outputs.flat_rank == 2
    var index = global_idx.x
    if index < Count:
        var result = core(Int(inputs[index]))
        comptime for lane in range(Width):
            outputs[index, lane] = result[lane]


def main() raises:
    var ctx = DeviceContext()
    if ctx.api() == 'cpu':
        raise Error('A GPU context is required; CPU execution is not a device result')
    print('GPU:', ctx.name(), '; API:', ctx.api())
    var host = ctx.enqueue_create_host_buffer[DType.int64](Count)
    var input = ctx.enqueue_create_buffer[DType.int64](Count)
    var output = ctx.enqueue_create_buffer[DType.int64](Count * Width)
    var inputs = TileTensor(host, InputLayout)
    comptime assert inputs.flat_rank == 1
    for index in range(Count):
        inputs[index] = Int64(index - 32)
    ctx.enqueue_copy(input, host)
    ctx.enqueue_function[kernel](TileTensor(input, InputLayout), TileTensor(output, OutputLayout), grid_dim=2, block_dim=64)
    # map_to_host waits for the queued kernel/copy before exposing host memory.
    with output.map_to_host() as mapped:
        var outputs = TileTensor(mapped, OutputLayout)
        comptime assert outputs.flat_rank == 2
        for index in range(Count):
            var value = expected(index - 32)
            comptime for lane in range(Width):
                assert_equal(outputs[index, lane], value[lane])
    print('device core: ok')
