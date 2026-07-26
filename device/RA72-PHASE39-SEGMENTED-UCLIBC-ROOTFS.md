# RA72 Phase 39 segmented uClibc rootfs build

## Exact target

- Product: Xiaomi **Mi AIoT AX6000**
- Model: **RA72**
- SoC: Qualcomm **IPQ5018**
- Board family: **MP03.1**

This target must not be confused with Xiaomi Mi Router AX6000
(IPQ8072A) or Redmi AX6000 (MT7986).

## Transfer correction

Phase 38 reached byte 435,467,981 of the official toolchain archive
before another server-side connection closure. Phase 39 uses multiple
small HTTP range pieces through aria2 rather than one long transfer.
Each failed piece is retried independently.

## Safety boundary

The workflow may produce only a review-only SquashFS rootfs component.
It blocks Qualcomm UBI packaging and does not create a boot-approved
RA72 image. It never contacts the router or changes SSH, UART, NAND,
bootloader variables, or partitions.
