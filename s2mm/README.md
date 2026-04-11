# mm2s / s2mm — HLS DMA Kernels

HLS PL kernels for streaming data between PS DDR and the AIE-ML v2 array.
Part of the `vd100-aie-pipeline` Vitis system project.

---

## Overview

| Kernel | Direction | Role |
|--------|-----------|------|
| `mm2s` | PS DDR → AXI4-Stream → AIE | Source — feeds price ticks into AIE graph |
| `s2mm` | AIE → AXI4-Stream → PS DDR | Sink — collects MA crossover results from AIE |

Both kernels are single-instance, pipelined (II=1), and controlled via XRT
AXI4-Lite slave interfaces.

---

## Kernel Signatures

```cpp
// mm2s — memory-mapped to stream
void mm2s(ap_int<32>* mem, hls::stream<ap_axis<32,0,0,0>>& s, int size);

// s2mm — stream to memory-mapped
void s2mm(ap_int<32>* mem, hls::stream<ap_axis<32,0,0,0>>& s, int size);
```

### Arguments

| Arg | Port | Interface | Notes |
|-----|------|-----------|-------|
| `mem` | AXI4 master | `m_axi / gmem` | DDR buffer pointer — `group_id(0)` for XRT BO |
| `s` | AXI4-Stream | `axis` | Connected to AIE PLIO by v++ linker |
| `size` | AXI4-Lite slave | `s_axilite / control` | **In bytes** — pass `count * sizeof(int32_t)` |
| `return` | AXI4-Lite slave | `s_axilite / control` | Completion signal |

> `size` is `int` in the HLS signature but XRT expects `unsigned int` at the call
> site. Cast explicitly: `static_cast<unsigned int>(count * sizeof(int32_t))`.

---

## Implementation

```cpp
// mm2s — reads int32 words from DDR, writes to AXI4-Stream
for (int i = 0; i < size; i++) {
#pragma HLS PIPELINE II=1
    ap_axis<32,0,0,0> x;
    x.data = mem[i];
    s.write(x);
}

// s2mm — reads from AXI4-Stream, writes int32 words to DDR
for (int i = 0; i < size; i++) {
#pragma HLS PIPELINE II=1
    ap_axis<32,0,0,0> x = s.read();
    mem[i] = x.data;
}
```

Both kernels run at II=1 (one word per clock cycle) with a 100 MHz PL clock.

---

## XRT Usage

```cpp
// Kernel handles (via hw_context)
auto mm2s_k = xrt::kernel(ctx, "mm2s:{mm2s_1}");
auto s2mm_k = xrt::kernel(ctx, "s2mm:{s2mm_1}");

// BO allocation — group_id(0) for both kernels
auto in_bo  = xrt::bo(ctx, input_samples * sizeof(int32_t),
                       static_cast<xrt::bo::flags>(0), mm2s_k.group_id(0));
auto out_bo = xrt::bo(ctx, output_vals  * sizeof(int32_t),
                       static_cast<xrt::bo::flags>(0), s2mm_k.group_id(0));

// ORDERING: s2mm FIRST — sink must be ready before source fires
// If mm2s fires first, AIE output stream backs up and stalls the graph.
xrt::run s2mm_run = s2mm_k(out_bo, nullptr,
                            static_cast<unsigned int>(output_vals * sizeof(int32_t)));
xrt::run mm2s_run = mm2s_k(in_bo,  nullptr,
                            static_cast<unsigned int>(input_samples * sizeof(int32_t)));
```

### Execution Order

```
1. s2mm start  ← sink ready first
2. mm2s start  ← source fires
3. graph.run() ← AIE graph
4. graph.wait()
5. s2mm_run.wait()
6. mm2s_run.wait()
```

---

## Address Map

Assigned in the Vitis system project address editor:

| Kernel | Base Address | Range |
|--------|-------------|-------|
| mm2s_1 / s_axi_control | 0xA401_0000 | 64K |
| s2mm_1 / s_axi_control | 0xA402_0000 | 64K |

---

## Build

Both kernels are compiled as part of `vd100_ma_system_project`.
Vitis runs HLS synthesis and exports the compiled kernel objects for v++ linking.

```
Vitis system project → v++ --compile --target hw mm2s.cpp
Vitis system project → v++ --compile --target hw s2mm.cpp
```

Source files: `mm2s/src/mm2s.cpp`, `s2mm/src/s2mm.cpp`
