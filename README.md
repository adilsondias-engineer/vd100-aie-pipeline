# vd100-aie-pipeline

End-to-end AIE-ML MA Crossover trading signal pipeline for the VD100 board
(Versal AI Edge XCVE2302-SFVA784-1LP-E-S).

Implements a dual moving-average crossover detector running on the AIE-ML array,
driven by HLS DMA kernels, controlled by an XRT host application on the A72 PS,
with results destined for an Ethereum smart contract on-chain log.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  PS (A72)                                                        │
│  vd100-ps-ma-client (XRT)                                        │
│      │  register_xclbin / hw_context / xrt::graph               │
└──────┼──────────────────────────────────────────────────────────┘
       │ AXI4-Lite (control)          AXI4 (DMA via NoC)
┌──────▼──────────────────────────────────────────────────────────┐
│  PL (Vitis Region)                                               │
│  ┌─────────┐    AXI4-Stream    ┌──────────────────────────┐     │
│  │  mm2s   │──────────────────►│   AIE-ML v2 (col 8)      │     │
│  │  (HLS)  │                   │   mygraph / ma_crossover │     │
│  └─────────┘                   │   fast MA(10) / slow MA(50)    │
│  ┌─────────┐    AXI4-Stream    │   → BUY / SELL / HOLD    │     │
│  │  s2mm   │◄──────────────────┤                          │     │
│  │  (HLS)  │                   └──────────────────────────┘     │
│  └─────────┘                                                     │
│  MyLEDIP  │  AXI Interrupt Controller                           │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  TradingSignalLog.sol (Hardhat / Ethereum)
```

---

## Repository Structure

```
vd100-aie-pipeline/
├── vd100_bd_aie_pipeline/     # Vivado block design — PL hardware platform
├── ip_repo/                   # Custom IP: MyLEDIP
├── mm2s/                      # HLS kernel: PS DDR → AXI4-Stream → AIE
├── s2mm/                      # HLS kernel: AIE → AXI4-Stream → PS DDR
├── vd100-aie-ma-crossover/    # AIE-ML v2 kernel: MA crossover graph
├── vd100-ps-ma-client/        # PS XRT host application (A72, C++20)
├── vd100_dts/                 # SDT / Device Tree output (sdtgen)
├── vd100_ma_system_project/   # Vitis system project — links all components
├── vd100_pipeline_platform/   # Pipeline platform (optional — see note)
└── vd100_platform/            # Base AIE platform (from aie-pipeline XSA)
└── meta-vd100_v3/             # v3 — + XRT 2025.2, zocl, AIE-ML v2 pipeline, BOOT.BIN CDO fix, Ethereum |
```

---

## Build Flow

```
1.  vd100-ps-aie-pipeline (Vivado)
        │  Export XSA
        ▼
2. vd100_platform (Vitis)
        │  Create platform from XSA
        ▼
3. vd100-aie-ma-crossover (Vitis AIE compiler)
   mm2s / s2mm (Vitis HLS)
        │  Compile kernels
        ▼
4. vd100_ma_system_project (Vitis v++ link + package)
        │  aie.xclbin + BOOT.BIN components
        ▼
5. Yocto (yoctoBuilder)
        │  xilinx-bootbin bbappend adds AIE CDOs
        │  BOOT.BIN → EFI partition on VD100
        ▼
6. vd100-ps-ma-client (on VD100)
        │  XRT loads xclbin, runs pipeline
        ▼
7. TradingSignalLog.sol (Hardhat on Venus)
```

---

## Hardware

| Item | Value |
|------|-------|
| Board | VD100 |
| Device | XCVE2302-SFVA784-1LP-E-S |
| AIE tile | col=8, row=0 |
| PL clock | 100 MHz |
| XRT | 2025.2 |
| Vitis | 2025.2 |
| Vivado | 2025.2 |
| Yocto | Scarthgap |
| Kernel | 6.12.40-xilinx (stock, no patches) |

### Address Map

| IP | Base Address | Range |
|----|-------------|-------|
| MyLEDIP | 0xA400_0000 | 4K |
| mm2s_1 / s_axi_control | 0xA401_0000 | 64K |
| s2mm_1 / s_axi_control | 0xA402_0000 | 64K |
| DDR (mm2s via NoC) | 0x0000_0000 | 2G |
| DDR (s2mm via NoC) | 0x0000_0000 | 2G |

---

## Critical Notes

### BOOT.BIN must include AIE CDO partitions

The Yocto `xilinx-bootbin` recipe does not include AIE CDOs by default.
Without them, all AIE tiles remain `clock_gated` after boot and the application
hangs silently. See `vd100-aie-ma-crossover/README.md` for the full fix.

Required in BOOT.BIN:
- `aie_dev_part` → `aie.cdo.device.partition.reset.bin`
- `aie_image` → `aie.merged.cdo.bin`

### zocl DT node requires sdtgen

```bash
sdtgen set_dt_param -dir sdt_out -zocl enable
```

Without `-zocl enable`, zocl probes with 4 hardcoded GIC SPI interrupts instead
of 32 IRQs from the AXI interrupt controller. This causes incorrect hardware state
reporting and kernel panics on AXI errors.

### No kernel patches required

Stock `linux-xlnx` kernel with the correct BOOT.BIN and zocl DT node is sufficient.
Any kernel workarounds for clock gating or AIE register access are symptoms of the
missing CDO issue described above.

### JTAG interference

Connecting Vitis JTAG while the XRT application is running causes the AIE array
to be reinitialised, producing zero output. Disconnect JTAG before running.

---

## Component READMEs

Each component has its own README:

| Component | Description |
|-----------|-------------|
| `vd100_bd_aie_pipeline/` | Vivado BD — platform hardware design |
| `mm2s/` | HLS DMA source kernel |
| `s2mm/` | HLS DMA sink kernel |
| `vd100-aie-ma-crossover/` | AIE-ML v2 kernel + BOOT.BIN fix |
| `vd100_platform/` | Platform creation from XSA |
| `vd100_ma_system_project/` | System integration, xclbin, packaging |
| `vd100_pipeline_platform/` | Optional pipeline platform |
| `vd100-ps-ma-client/` | XRT host application |
| `meta-vd100_v3/`      | v3 — + XRT 2025.2, zocl, AIE-ML v2 pipeline, BOOT.BIN CDO fix, Ethereum |
