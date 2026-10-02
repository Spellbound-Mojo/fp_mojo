# Device example

This example runs ordinary public FP operations inside a GPU kernel. It adds no
device-specific invocation, composition, partial, fold or ADT code: the same
library functions compile for the host and for the device.

The example has three files:

- `core.mojo` holds one allocation-free calculation built from `as_unary`, `flow`,
  `compose`, `flip`, `partial`, `fold_left`, `Result`, `Choice` and `fp.match`, plus an
  independent arithmetic `expected` function;
- `run.mojo` launches that calculation as a GPU kernel, with explicit transfers
  and synchronization;
- `host.mojo` runs the same calculation on the CPU as a control.

## Requirements

Mojo stays pinned to 1.1.0. Its GPU APIs ship in **max-core 26.6.0**, which only
the optional Pixi `device` environment installs; the default environment and the
`fp` package do not depend on MAX. Running `run.mojo` needs a GPU that Mojo
supports, with its driver and runtime (see the
[Mojo GPU requirements](https://mojolang.org/docs/requirements/)).

## Run

On a machine with a supported GPU:

```sh
pixi run -e device mojo run --Werror -O3 -I src docs/examples/device/run.mojo
```

The program prints the device name and API, copies 65 inputs (−32 to 32) to the
device, launches the kernel, maps the results back and checks every output. It
rejects a CPU context, and the kernel asserts at compile time that it is being
compiled for a GPU. `map_to_host` performs the host-side synchronization.

Cross-compiling needs no GPU:

```sh
mkdir -p .cache/device
pixi run -e device mojo build --Werror -O3 -I src --target-accelerator=sm_80 --emit asm docs/examples/device/run.mojo -o .cache/device/core.s
```

This writes host assembly and a separate PTX file for the device; use `gfx1030`
for AMD assembly. Cross-compilation shows the code is device-compatible; it is not
a device run. See [compilation targets](https://mojolang.org/docs/tools/compilation/).

## The shared calculation

All callbacks are non-raising, all values are fixed-size or borrowed, and every
callable and ADT owner is constructed inside the thread that uses it. Only numeric
buffers cross the host/device boundary.

| Operation | Specialization used |
|---|---|
| `as_unary` | Owned `Int` input and result, called through `call` |
| `flow`, `compose` | Two plain non-raising functions in each order; the zero-stage identity |
| `flip` | A plain two-parameter `Int` function with its arguments swapped |
| `partial` | A copied `Int`; changing the original afterwards does not affect two later calls |
| `fold_left` | A native range, an `Int` accumulator and a non-commutative step, on empty and non-empty ranges |
| `Result`, `Ok`, `Err`, `fold`, `is_ok` | Both branches of an `Int`/`Int` result with non-raising callbacks |
| `Choice`, `fp.match` | Two record constructors with `Int` fields stored in place, both branches |
| SIMD invocation and composition | `SIMD[int32, 4]`, keeping every lane and the exact intermediate type |

Each input produces 16 outputs: invocation, flow, compose, flip, two partial calls,
the fold, Result elimination, constructor elimination, four SIMD lanes, the empty
fold, the identity, the changed original capture and the Result tag.

<!-- source: docs/examples/device/core.mojo -->

## The kernel launch

<!-- source: docs/examples/device/run.mojo -->

## The CPU control

The control checks the same calculation against `expected` for every input on the
host. It is part of the documentation tests; the GPU program is not, because the
test machines have no supported GPU.

<!-- example: docs/examples/device/host.mojo -->

## What this does not show

The library adds no implicit transfer, launch, synchronization, allocation,
parallel fold, exception bridge or horizontal SIMD reduction. Other
specializations are not established for devices: capturing closures, mutable or
consuming callable receivers, origin-carrying results, dynamically allocated
containers, strings, recursive data, raising callbacks and owners transferred from
the host. Execution of this example on GPU hardware has not been verified yet;
see [support and limitations](../guides/status.md).
