# VD100 AIE Pipeline — System Architecture

**PL → AIE-ML v2 → PS → Ethereum Smart Contract**  
Versal AI Edge XCVE2302-SFVA784-1LP-E-S | VD100 Board | April 2026  
Adilson de Souza Dias | adilsondias-engineer

---

## 1. Project Objective

Build the first documented end-to-end PL + AIE-ML v2 + PS integration on an
accessible Versal AI Edge board (XCVE2302, AUD $1,285). AMD's official training
material covers each subsystem in isolation — no public reference exists for the
full three-layer integration on non-VCK190 hardware.

The pipeline implements a dual moving-average crossover trading signal detector:
price ticks stream from PS DDR through HLS DMA kernels into the AIE-ML v2 array,
which computes fast MA (10-period) and slow MA (50-period) and emits a BUY/SELL/HOLD
signal. Results are logged on-chain via an Ethereum smart contract on a local
Hardhat node.

> **First-mover:** All existing AMD Vitis tutorials for Versal target VCK190
> (USD $15,000) + MATLAB/Simulink. This project uses VD100 (AUD $1,285) +
> open-source toolchain. First documented MA crossover on AIE-ML v2.

---

## 2. End-to-End Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PS (Cortex-A72) — Yocto Linux                                              │
│                                                                              │
│  vd100-ps-ma-client (XRT, C++20)                                            │
│    register_xclbin → hw_context → xrt::graph                                │
│    in_bo (price ticks) → sync to device                                     │
│    s2mm start → mm2s start → graph.run(-1)                                  │
│    graph.wait → s2mm.wait → mm2s.wait                                       │
│    sync from device → print results                                          │
│    eth_post_signal() → JSON-RPC → TradingSignalLog.sol    [NEXT STEP]       │
└──────────┬────────────────────────────────────────────────────────┬─────────┘
           │ AXI4-Lite (XRT control)          AXI4 NoC (DMA data)  │
┌──────────▼────────────────────────────────────────────────────────▼─────────┐
│  PL — Vitis Region (100 MHz)                                                │
│                                                                              │
│  ┌──────────────┐   AXI4-Stream    ┌─────────────────────────────────────┐ │
│  │   mm2s (HLS) │─────────────────►│   AIE-ML v2 Array (col 8, row 0)   │ │
│  │  PS DDR→AIE  │                  │                                     │ │
│  └──────────────┘                  │   MAGraph / ma_crossover<50>        │ │
│                                    │   fast MA (10 periods)              │ │
│  ┌──────────────┐   AXI4-Stream    │   slow MA (50 periods)              │ │
│  │   s2mm (HLS) │◄─────────────────│   → BUY / SELL / HOLD              │ │
│  │  AIE→PS DDR  │                  │                                     │ │
│  └──────────────┘                  └─────────────────────────────────────┘ │
│                                                                              │
│  MyLEDIP (0xA400_0000) — PL health indicator                                │
│  AXI Interrupt Controller (32 IRQs → PS) — required for zocl               │
└─────────────────────────────────────────────────────────────────────────────┘
           │
           │ JSON-RPC HTTP POST (libcurl)         [NEXT STEP]
           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Workstation (i9-14900KF) — Venus                                           │
│                                                                              │
│  Hardhat local chain  http://0.0.0.0:8545                                   │
│  TradingSignalLog.sol deployed at 0x5FbDB2315678afecb367f032d93F642f64180aa3│
│  recordSignal(fast_ma, slow_ma, signal, action) → on-chain audit trail      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Build Status

| Layer | Component | Status |
|-------|-----------|--------|
| PL hardware | `aie-pipeline` Vivado BD | Complete |
| Vitis platform | `vd100_platform` | Complete |
| AIE kernel | `vd100-aie-ma-crossover` | Complete — golden verified |
| HLS kernels | `mm2s`, `s2mm` | Complete |
| System integration | `vd100_ma_system_project` | Complete — `aie.xclbin` live |
| Yocto boot image | BOOT.BIN + AIE CDOs | Complete — bbappend deployed |
| PS host app | `vd100-ps-ma-client` | Complete — golden output confirmed |
| Ethereum layer | `TradingSignalLog.sol` + libcurl | **Next step** |

---

## 4. Component Details

### 4.1 Vivado Block Design (`aie-pipeline`)

Hardware platform for the VD100. Key design elements:

- **CIPS** — A72 APU + PMC. `M_AXI_FPD` explicitly enabled (disabled by default;
  omitting it causes PMC EAM ERR1 kernel panics on PS→PL access).
- **NoC** — DDR access for mm2s/s2mm DMA. PLIO connections to AIE resolved by v++.
- **AXI Interrupt Controller** — 32 IRQs connected to PS. Required for zocl driver.
- **MyLEDIP** — custom IP from ip_repo. PL health indicator (LED off = PL in reset).
- **PL clock: 100 MHz** — 156.25 MHz caused GEM0 TX clock failure (RX=0 symptom).

### 4.2 Vitis Platform (`vd100_platform`)

Extensible platform built from the `aie-pipeline` XSA. Consumed by the AIE compiler
and the system project v++ link step.

```
vd100_platform/export/vd100_platform/vd100_platform.xpfm
```

### 4.3 AIE-ML v2 Kernel (`vd100-aie-ma-crossover`)

MA crossover graph running on AIE tile col=8, row=0.

```
ADF graph: MAGraph / mygraph
Kernel:    ma_crossover<SLOW_MA_PERIOD=50>
Input:     BLOCK_SIZE=56 int32 samples per iteration
Margin:    50 samples (history carried between iterations via ADF margin)
Output:    3 x int32 per iteration — { fast_ma, slow_ma, signal }
```

Signal encoding: `1=BUY, -1=SELL, 0=HOLD`

Crossover detection:
```
BUY:  prev_fast_ma <= prev_slow_ma  AND  fast_ma > slow_ma
SELL: prev_fast_ma >= prev_slow_ma  AND  fast_ma < slow_ma
HOLD: otherwise
```

### 4.4 HLS DMA Kernels (`mm2s`, `s2mm`)

```cpp
void mm2s(ap_int<32>* mem, hls::stream<ap_axis<32,0,0,0>>& s, int size);
void s2mm(ap_int<32>* mem, hls::stream<ap_axis<32,0,0,0>>& s, int size);
```

Both: `size` in **bytes** (`count * sizeof(int32_t)`). II=1, 100 MHz.  
s2mm must start **before** mm2s — sink must be ready before source fires.

### 4.5 System Project (`vd100_ma_system_project`)

v++ link + package. Produces:

| Output | Purpose |
|--------|---------|
| `aie.xclbin` | Loaded at runtime by XRT on VD100 |
| `aie.merged.cdo.bin` | BOOT.BIN `aie_image` partition |
| `aie.cdo.device.partition.reset.bin` | BOOT.BIN `aie_dev_part` partition |

xclbin UUID: `0f5096a5-b416-a54c-8035-9efc0e394fdc`

### 4.6 PS Host Application (`vd100-ps-ma-client`)

XRT host application (C++20, A72, Yocto Linux). XRT 2025.2 API:

```cpp
xrt::device device(0);
xrt::xclbin xclbin_obj{xclbin_path};
auto uuid = device.register_xclbin(xclbin_obj);
xrt::hw_context ctx(device, uuid);
auto mm2s_k = xrt::kernel(ctx, "mm2s:{mm2s_1}");
auto s2mm_k = xrt::kernel(ctx, "s2mm:{s2mm_1}");
// ... allocate BOs, run kernels, run graph, collect results
```

### 4.7 Ethereum Smart Contract (`TradingSignalLog.sol`) — NEXT STEP

```solidity
// Deployed: 0x5FbDB2315678afecb367f032d93F642f64180aa3
// Network:  Hardhat local node on Venus (http://<venus-ip>:8545)

contract TradingSignalLog {
    struct Signal {
        uint256 timestamp;
        int256  fast_ma;
        int256  slow_ma;
        int256  signal_value;   // 1=BUY, -1=SELL, 0=HOLD
        string  action;         // "BUY" / "SELL" / "HOLD"
        address source;         // VD100 PS caller address
    }
    Signal[] public signals;
    event SignalRecorded(uint256 indexed id, int256 fast_ma, int256 slow_ma,
                         int256 signal_value, string action);

    function recordSignal(int256 fast_ma, int256 slow_ma,
                          int256 signal_value, string calldata action) external;
    function getSignalCount() external view returns (uint256);
    function getSignal(uint256 id) external view returns (...);
}
```

PS integration — one function added to `vd100-ps-ma-client` after the results table:

```cpp
// Current (complete):
printf("|  %5d  |  %6d  |  %6d  |  %s  |\n", b+1, fast_ma, slow_ma, signal_str(signal));

// Next step — add after results loop:
for (int b = 0; b < num_blocks; ++b) {
    if (out[b * OUTPUT_VALS + 2] != SIGNAL_HOLD) {  // only log BUY/SELL
        eth_post_signal(out[b*OUTPUT_VALS+0],        // fast_ma
                        out[b*OUTPUT_VALS+1],        // slow_ma
                        out[b*OUTPUT_VALS+2],        // signal value
                        signal_str(out[b*OUTPUT_VALS+2])); // action string
    }
}
```

`eth_post_signal()` makes a raw JSON-RPC HTTP POST via libcurl — no Node.js on VD100.

---

## 5. Hardhat Setup (Venus Workstation)

```bash
# Hardhat node running on Venus, accessible on LAN
npx hardhat node --hostname 0.0.0.0
# → http://<venus-ip>:8545

# Deploy contract
npx hardhat run scripts/deploy.js --network localhost

# Verify (from workstation)
npx hardhat console --network localhost
> const c = await ethers.getContractAt("TradingSignalLog", "0x5FbDB...")
> await c.getSignalCount()   // returns count of recorded signals
```

VD100 PS connects to `http://<venus-ip>:8545` via GbE. No dependency on public
testnet — local chain only, zero gas cost, instant block mining.

---

## 6. Address Map

| IP | Base Address | Range |
|----|-------------|-------|
| MyLEDIP | 0xA400_0000 | 4K |
| mm2s_1 / s_axi_control | 0xA401_0000 | 64K |
| s2mm_1 / s_axi_control | 0xA402_0000 | 64K |
| DDR (mm2s via NoC) | 0x0000_0000 | 2G |
| DDR (s2mm via NoC) | 0x0000_0000 | 2G |

---

## 7. Hardware & Toolchain

| Item | Value |
|------|-------|
| Board | VD100 |
| Device | XCVE2302-SFVA784-1LP-E-S |
| AIE tile | col=8, row=0 |
| PL clock | 100 MHz |
| Vivado | 2025.2 ML Enterprise |
| Vitis | 2025.2 |
| XRT | 2025.2 |
| Yocto | Scarthgap |
| Linux kernel | 6.12.40-xilinx (stock, no patches) |
| Timing (WNS) | 4.217 ns |
| Timing (WHS) | 0.018 ns |
| Hardhat | 3.x (Venus, i9-14900KF) |
| Contract address | 0x5FbDB2315678afecb367f032d93F642f64180aa3 |

---

## 8. Critical Lessons Learned

### BOOT.BIN must include AIE CDO partitions

The single most impactful undocumented issue. Yocto `xilinx-bootbin` does not
include AIE CDOs by default. Without them:

- PLM boots, processes only `aie2_subsys.cdo` (470 bytes of subsystem init)
- All AIE tiles remain `clock_gated` permanently after boot
- XRT `graph.run()` triggers XAIEFAL to storm ioctl retries against gated tiles
- Application hangs silently — no error, no panic, no timeout

Fix: `xilinx-bootbin_1.0.bbappend` in `meta-vd100_v3` adds `aie_dev_part` and
`aie_image` partitions to the Yocto-generated BIF. See `vd100-aie-ma-crossover/README.md`.

### sdtgen `-zocl enable` is mandatory

```bash
sdtgen set_dt_param -dir sdt_out -zocl enable
```

Without it: 4 hardcoded GIC SPI IRQs instead of 32 from AXI interrupt controller.
Result: wrong hardware state reporting, kernel panics on AXI errors.

### No kernel patches required

Stock `linux-xlnx` kernel is correct. All prior workarounds (clock gating patches,
SET_COLUMN_CLOCK ioctl, xrtResetAIEArray) were symptoms of the missing CDO issue.

### JTAG interference

Connecting Vitis JTAG while XRT application is running causes AIE array
reinitialisation → zero output. Disconnect JTAG before running.

### xclbin and BOOT.BIN must match

Rebuilding `vd100_ma_system_project` produces a new xclbin **and** new CDO files.
Both must be updated together. Running new xclbin against old BOOT.BIN CDOs will fail.

---

## 9. Phased Delivery

| Phase | Scope | Status |
|-------|-------|--------|
| 1 — AIE Proof | PL→AIE→PS data path, golden test vector | **Complete** |
| 2 — Ethereum Integration | PS posts signals to `TradingSignalLog.sol` via libcurl | Next |
| 3 — End-to-End Demo | Full pipeline with on-chain signal log | Pending Phase 2 |
| 4 — Tutorial Publication | AMD Vitis Contributed Tutorial submission | Pending Phase 3 |
| 5 — 10GbE Ingress (future) | Replace PS XRT input with SFP+ GTYP 10GbE market data | Future |

---

## 10. Decision Log

| Decision | Chosen | Rationale |
|----------|--------|-----------|
| AIE kernel | MA crossover (custom) vs AMD weighted_sum | MA crossover is a real trading signal — more relevant to the portfolio narrative than a generic dot product |
| DMA approach | HLS mm2s/s2mm vs AXI DMA IP | HLS kernels integrate cleanly with Vitis v++ linker; connectivity resolved automatically |
| PL clock | 100 MHz vs 156.25 MHz | 156.25 MHz caused GEM0 TX failure; 100 MHz stable across all peripherals |
| Local chain | Hardhat vs Ganache | Ganache deprecated by ConsenSys 2023; Hardhat is the endorsed successor |
| PS→ETH transport | libcurl JSON-RPC vs Node.js | No Node.js on aarch64 Yocto rootfs; libcurl is standard, no extra dependencies |
| Solidity target | Local Hardhat vs public testnet | Zero gas, instant mining, no network dependency; identical ABI if mainnet deployment desired |

---

## 11. Repository Structure

```
vd100-aie-pipeline/                  ← this repo
├── aie-pipeline/                    Vivado BD — PL hardware platform
├── ip_repo/                         Custom IP: MyLEDIP
├── mm2s/                            HLS kernel: PS DDR → AIE
├── s2mm/                            HLS kernel: AIE → PS DDR
├── vd100-aie-ma-crossover/          AIE-ML v2 MA crossover kernel
├── vd100-ps-ma-client/              XRT PS host application
├── vd100_dts/                       SDT / DTS output (sdtgen -zocl enable)
├── vd100_ma_system_project/         Vitis system project (xclbin + CDOs)
├── vd100_pipeline_platform/         Optional — post-link platform snapshot
├── vd100_platform/                  Base AIE platform (from aie-pipeline XSA)
└── ARCHITECTURE.md                  This document
```

---

*Created: April 4, 2026 (original plan) | Updated: April 11, 2026 (Phase 1 complete)*  
*Adilson de Souza Dias | VD100 Project 3 | Context Recovery Document*
