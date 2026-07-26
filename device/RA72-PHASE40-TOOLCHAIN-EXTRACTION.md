# RA72 Phase 40 toolchain extraction and rootfs build

## Exact target

- Product: Xiaomi **Mi AIoT AX6000**
- Model: **RA72**
- SoC: Qualcomm **IPQ5018**
- Board family: **MP03.1**

This target must not be confused with Xiaomi Mi Router AX6000
(IPQ8072A) or Redmi AX6000 (MT7986).

## Toolchain result

The official archive currently contains a Cortex-A53 GCC 15.2 toolchain
whose directory name mentions musl. It also exposes the historical
`aarch64-linux-uclibc-*` compatibility commands required by the current
DD-WRT `Makefile.ipq60xx`. Phase 40 selects the compiler by the required
command name and verifies it by compiling and inspecting a small ARM64
program before beginning the DD-WRT build.

## Safety boundary

The workflow may produce only a review-only SquashFS rootfs component.
It blocks Qualcomm UBI packaging and does not create a boot-approved
RA72 image. It never contacts the router or changes SSH, UART, NAND,
bootloader variables, or partitions.
