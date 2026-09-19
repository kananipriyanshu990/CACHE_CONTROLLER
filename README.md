# 4KB Write-Back Cache Controller with OpenRAM SRAM Macros

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
