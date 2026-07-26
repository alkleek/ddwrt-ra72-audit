# RA72 Phase 37 native uClibc rootfs build

## Exact target

- Product: Xiaomi **Mi AIoT AX6000**
- Model: **RA72**
- SoC: Qualcomm **IPQ5018**
- Board family: **MP03.1**

This target must not be confused with:

- Xiaomi Mi Router AX6000 using IPQ8072A
- Redmi AX6000 using MediaTek MT7986

The filename and some upstream source identifiers may contain
`xiaomi_ax6000`, but this project accepts them only where the associated
device definition resolves to RA72/IPQ5018.

## Phase 36 findings addressed

Phase 36 reached the real DD-WRT make invocation and proved that four
build prerequisites were missing or wrong:

1. `aarch64-linux-uclibc-gcc` was unavailable.
2. the selected build did not have the required
   `src/linux/universal/linux-6.12-nss` source tree;
3. `src/opt` was absent;
4. the host DD-WRT configuration utility linked with modern GCC without
   `-fcommon`.

Phase 37 addresses all four conditions in one run and records the next
real blocker if the rootfs still does not build.

## Safety boundary

The workflow may produce only a review-only SquashFS rootfs component.
It blocks Qualcomm UBI packaging and does not create a boot-approved
RA72 image. It never contacts the router or changes SSH, UART, NAND,
bootloader variables, or partitions.
