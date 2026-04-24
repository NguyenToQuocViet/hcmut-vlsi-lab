# CLAUDE.md — vlsi_lab

Lab thực hành môn VLSI tại HCMUT. Mỗi bài lab là một thiết kế RTL độc lập, implement trên FPGA Xilinx Zynq-7020 (xc7z020clg400-1).

---

## Toolchain

- **Simulator / Synthesizer**: Xilinx Vivado (xsim)
- **Target FPGA**: `xc7z020clg400-1`
- **HDL**: SystemVerilog
- **Workflow**: **Non-project** (in-memory, không dùng `.xpr`)

---

## Cấu trúc thư mục

```
vlsi_lab/
├── Makefile              — Template Makefile, copy vào từng lab trước khi build
├── create_project.tcl    — Vivado project scaffold
├── ring_buffer/          — Lab 1: Ring LED flasher (ring_flasher)
│   ├── rtl/
│   ├── tb/
│   ├── tcl/
│   ├── constrs/
│   └── work/
└── spi/                  — Lab 2: SPI Master-Slave (WIP)
    ├── rtl/
    ├── tb/
    └── tcl/
```

**Per-lab layout (chung):**
```
<lab>/
├── rtl/          — RTL sources (*_pkg.sv load trước)
├── tb/           — Testbenches (*_tb.sv)
├── tcl/          — Vivado batch scripts (non-project)
│   ├── elaborate.tcl
│   ├── lint.tcl
│   ├── sim.tcl
│   ├── synth.tcl
│   └── impl.tcl
├── work/         — Output directory (tạo thủ công nếu chưa có)
│   ├── reports/
│   └── checkpoints/
├── constrs/      — XDC constraints (nếu có)
└── Makefile      — Copy từ root Makefile
```

---

## Build commands

Chạy từ **trong thư mục lab** (e.g., `cd spi`). Nếu `Makefile` chưa có, copy từ root: `cp ../Makefile .`
`work/` tự tạo bởi mỗi target — không cần `mkdir` thủ công.

```bash
make build              # RTL elaborate (syntax check)
make lint               # Lint: latch, methodology, full DRC
make run                # Simulation batch mode (TB = config.tcl DEFAULT_TB)
make sim                # Simulation + waveform GUI
make synth              # Synthesis → work/checkpoints/post_synth.dcp
make impl               # Implementation (yêu cầu synth trước)
make clean              # Xóa sim artifacts
make distclean          # Xóa toàn bộ work/
```

**Override TOP / TB** (không cần edit `config.tcl`):
```bash
make run  TB=spi_master_tb        # chọn TB cụ thể (sim batch)
make sim  TB=spi_slave_tb         # chọn TB cụ thể (GUI)
make synth TOP=spi_master         # synth riêng 1 sub-module
make lint  TOP=spi_slave          # lint riêng 1 sub-module
```

**TCL infrastructure (per lab):**
- `tcl/config.tcl` — single source of truth: `TOP`, `DEFAULT_TB`, `PART` + helper procs (`find_files`, `gather_sv`, `load_rtl_sources`, `resolve_top`)
- `tcl/{elaborate,lint,sim,synth,impl}.tcl` — sourced từ `config.tcl`, **đệ quy** quét `../rtl/**/*.sv`, `../tb/**/*.sv`, `../constrs/**/*.xdc`
- Compile order: `*_pkg.sv` → modules; RTL → TB. Nếu package có inter-dependency, đặt tên alphabetical theo dependency (e.g. `0_base_pkg.sv`, `1_derived_pkg.sv`)
- Hidden dirs (`.git`, `.Xil`) và `work/` tự skip khi traverse

---

## Quy tắc RTL (Vivado strict)

1. **Khai báo trước khi dùng** — xvlog xử lý top-down, không forward reference.
2. **`timescale`** — mọi file `.sv` (kể cả package) phải có `` `timescale 1ns/1ps ``.
3. **LUTRAM inference** — array 1D unpacked, đọc combinational, ghi trong `always_ff` không có `negedge rst_n`.
4. **"Set and reset same priority"** — tách `always_ff` thành 2 block: block 1 có async reset (control signals), block 2 clock-only (data arrays).
5. **Simulation speed** — dùng `` `ifdef SIMULATION `` trong package để rút ngắn TICK_MAX; pass `-d SIMULATION` vào `xvlog` trong `sim.tcl`.

---

## Lab 1: ring_buffer (ring_flasher)

<!-- Update this section when ring_flasher design changes -->

### Spec
16 LED xếp vòng tròn, PWM 6 mức sáng (0–5), clock 5 MHz, step 0.5s.
- `rep=1` → bắt đầu: **12 bước CW** (FORWARD) → **8 bước CCW** (BACKWARD)
- Cuối BACKWARD: `rep=1` → lặp cycle; `rep=0` → DECAY (fade dần) → IDLE
- Reset active-low

### Files
| File | Mô tả |
|------|-------|
| `rtl/ring_flasher_pkg.sv` | Package: params + `state_t` typedef |
| `rtl/ring_flasher.sv` | Module `counter` + `ring_flasher` |
| `tb/ring_flasher_tb.sv` | 12 test cases (TC1–TC12) |

### FSM
```
IDLE ──(rep=1)──► FORWARD ──(12 ticks)──► BACKWARD
  ▲                                           │
  │                          rep=1 ◄──────────┤
  │                          rep=0 ──► DECAY ─┘(all_off)
```

### Key design notes
- `pos_ptr` reset về `NUM_LEDS-1=15` → tick FORWARD đầu tiên: `(15+1)%16=0` → led[0] sáng
- `next_pos` combo tính vị trí mới để brightness update dùng — cần declare TRƯỚC `always_ff` dùng nó
- `step_cnt` reset về 0 khi `state != next_state` (transition cycle)
- PWM: `pwm_cnt` chạy 0→4, `leds[i] = (led_brightness[i] > pwm_cnt)` → 6 mức duty cycle
- DECAY → IDLE cần `BRIGHTNESS_LEVELS+1` ticks: 5 ticks để về 0, tick thứ 6 mới register IDLE

### Simulation (TICK_MAX override)
```
Binh thuong:  TICK_MAX = 2,500,000 cycles (500ms @ 5MHz)
Simulation:   TICK_MAX = 20 cycles
```
`wait_ticks(n)` trong TB dùng `@(posedge clk iff dut.tick)` — sync với tick thực.

---

## Lab 2: spi (SPI Master-Slave)

### Spec
- Data width: 8 bits/transaction, MSB-first, SPI Mode 0 (CPOL=0, CPHA=0)
- Sample posedge SCLK, shift negedge SCLK
- Reset: async assert, sync deassert, active-LOW (`rst_n`)
- Top module chứa cả `spi_master` + ≥2 `spi_slave` instances (test SS decoder)

### Files
| File | Mô tả |
|------|-------|
| `rtl/spi_master.sv` | SPI master — FSM + shift register (WIP) |
| `rtl/spi_slave.sv` | SPI slave — IDLE/TRANSFER FSM |
| `rtl/spi_top.sv` | Top: master + ≥2 slave instances |
| `tb/spi_master_tb.sv` | Isolated master TB |
| `tb/spi_slave_tb.sv` | Isolated slave TB |
| `tb/spi_top_tb.sv` | Full integration + edge case TB |

### SPI Master — Ports

| Group | Signal | Dir | Description |
|-------|--------|-----|-------------|
| System | `ref_clk` | in | System clock |
| System | `rst_n` | in | Active-low reset |
| System | `in[7:0]` | in | TX data / slave index input |
| System | `out[7:0]` | out | RX data (combinational, = `tx_reg` after transaction) |
| System | `cntl[1:0]` | in | Opcode |
| System | `ready` | out | 1 = IDLE, 0 = busy |
| SPI | `sclk` | out | Gated: `ref_clk` when TRANSFER, else 0 |
| SPI | `mosi` | out | `tx_reg[7]` combinational |
| SPI | `miso` | in | Sampled into `tx_reg` LSB |
| SPI | `ss[7:0]` | out | One-cold slave select |

### CNTL Opcode (master)
| Code | Action |
|------|--------|
| `2'b00` | NOP |
| `2'b01` | Load `in` → `tx_reg` (IDLE only) |
| `2'b10` | Load `in` → `slave_idx` (IDLE only) |
| `2'b11` | Start transfer; `ready=0` until shift done AND `cntl≠2'b11` |

### SPI Master — FSM
```
IDLE → TRANSFER → WAIT_CLEAR → IDLE
```
- IDLE: `ready=1`, accept load commands
- TRANSFER: shift 8 bits, `ready=0`, `ss` active
- WAIT_CLEAR: anti-retrigger — wait for `cntl≠2'b11` before returning IDLE

### SPI Master — Data path
- `tx_reg[7:0]`: shift register MSB-first — `tx_reg <= {tx_reg[6:0], miso}`
- `slave_idx[7:0]`: binary slave index, reset = `8'hFF` (safe: no slave selected)
- `timer[2:0]`: bit counter 0–7, reset when not TRANSFER
- `ss = (state==TRANSFER) ? ss_onehot : 8'hFF`
- `ss_onehot = (slave_idx<8) ? ~(8'b1 << slave_idx[2:0]) : 8'hFF`
- `sclk = (state==TRANSFER) ? ref_clk : 1'b0`
- `slave_idx` và `tx_reg` **persist** qua transactions (sticky — load once, reuse)

### SPI Slave — Ports

| Signal | Dir | Description |
|--------|-----|-------------|
| `clk` | in | System clock |
| `rst_n` | in | Active-low reset |
| `in[7:0]` | in | TX data to preload |
| `out[7:0]` | out | RX data received from master |
| `load` | in | 1 = latch `in` → `tx_reg` (when IDLE) |
| `ready` | out | 1 = IDLE and ready |
| `sclk` | in | SPI clock from master |
| `mosi` | in | Data from master |
| `miso` | out | Data to master |
| `cs` | in | Active-low chip select |

### SPI Slave — Behavior
- `load=1` + `ready=1` → latch `in` vào `tx_reg`
- `cs=0` → start transaction, `ready=0`, shift on SCLK edges
- `cs=1` hoặc 8 bits done → back to IDLE, `out` = received byte
- **Slave phải có `tx_reg` valid trước cạnh SCLK đầu tiên** (preload trước khi master start)
- 2 states: IDLE, TRANSFER

### Testcase plan
| TC | Scope | Description |
|----|-------|-------------|
| 1 | Master isolated | TB drives MISO, verify MOSI/SS/SCLK waveform |
| 2 | Slave isolated | TB drives SCLK/MOSI/CS, verify MISO + out |
| 3 | Full integration | master + 2 slaves in top, full handshake |
| 4 | Loopback | MOSI↔MISO shorted at top, byte sent == byte received |
| 5 | Edge: invalid slave | `slave_idx≥8` → `ss=8'hFF`, no transaction |
| 6 | Edge: no clear | host holds `cntl=2'b11` → WAIT_CLEAR blocks re-trigger |
| 7 | Edge: back-to-back | consecutive transactions without extra delay |
| 8 | Edge: slave not preloaded | slave `tx_reg` uninitialized before CS assert |
