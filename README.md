# 4KB Cache Controller with SRAM Macros

## Overview

This project implements a **4KB direct-mapped, write-back cache controller** for a 32-bit processor interface. The design supports cache hits, misses, line refill, dirty-line write-back, write allocation, and CPU/memory handshaking.

Unlike a conventional RTL-only cache implementation where the entire data array is synthesized using flip-flops or LUTs, the cache data storage is implemented using **four 1KB OpenRAM SRAM macros**. This allows the design to follow a more realistic ASIC memory implementation flow.

The complete design was taken through RTL development, verification, synthesis, SRAM macro integration, and physical design using an open-source ASIC flow.

---

## Key Specifications

| Parameter                      | Specification             |
|--------------------------------|---------------------------|
| Cache capacity                 | 4KB                       | 
| Cache organization             | Direct-mapped             |
| CPU address width              | 32 bits                   |
| Cache line size                | 32 bytes                  |
| Words per cache line           | 8 × 32-bit words          |
| Number of cache lines          | 128                       |
| Data width                     | 32 bits                   |
| Tag                            | 20 bits                   |
| Index                          | 7 bits                    |
| Word offset                    | 3 bits                    |
| Byte offset                    | 2 bits                    |
| SRAM organization              | 4 × 1KB                   |
| Individual SRAM                | 256 × 32-bit              |
| SRAM generator                 | OpenRAM                   |
| Technology                     | FreePDK45  Nangate45 flow |

---

# RTL Module Description

## 1. Address Decoder

### Function

Converts the CPU address into cache-access parameters.

### Outputs

- Tag
- Index
- Word Offset

---

# 2. Cache Memory

The cache memory module implements the actual storage array.

It contains:

- Data array
- Tag array
- Valid bits
- Dirty bits

### Responsibilities

- Provide cache data during reads
- Store refill data
- Update metadata
- Provide current cache line information to controller

---

# 3. Cache Controller

The controller is the decision-making unit of the cache.

It is implemented using a finite state machine.

### Responsibilities

- Detect cache hits and misses
- Decide between refill and writeback
- Generate cache update signals
- Generate memory requests
- Manage transaction completion

---

# Tools Used
- Xilinx Vivado for RTL design & Simulation
- Yosys for Netlist synthesis
- Openroad for Physical design
- Klayout Visual inspection of Design
