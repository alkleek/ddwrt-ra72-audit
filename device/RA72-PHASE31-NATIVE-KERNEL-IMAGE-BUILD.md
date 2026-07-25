# Phase 31 native DD-WRT kernel-build contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

This is not the Xiaomi Mi Router AX6000 (IPQ8072A), Redmi AX6000, or any
device whose label does not state RA72.

## Phase 30 result

Phase 30 proved that the exact RA72 Device Tree builds through the native
DD-WRT Linux 6.12 NSS kernel tree:

- native `.config_ipq6018` preparation passed;
- native Kbuild DTB target passed;
- decompile and round-trip validation passed;
- exact model, compatible strings, Ethernet topology, and Q6 memory
  regions passed all 22 checks.

## Phase 31 scope

Phase 31 uses the same verified source patch and native DD-WRT kernel tree,
but asks Kbuild to compile:

- the raw ARM64 Linux `Image`;
- `qcom/ipq5018-xiaomi-ra72.dtb`.

It also audits the resolved kernel configuration for the built-in storage,
Qualcomm, Ethernet, MDIO, PHY, and remote-processor foundations required by
RA72. Drivers configured as modules are recorded for the next phase.

## Safety boundary

The raw kernel Image is a **review artifact**, not complete DD-WRT firmware.
No root filesystem, modules package, FIT image, UBI, BIN, ITB, TRX, or IMG
is produced. No router, SSH session, UART, NAND partition, or boot variable
is accessed. Nothing from this phase is approved for booting or flashing.
