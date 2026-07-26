# RA72 Phase 38 resumable uClibc rootfs build

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

## Phase 37 result

Phase 37 pinned DD-WRT SVN revision `65774`, but the official toolchain
download stopped after about 18 MB with curl error 92. No source build,
rootfs generation, image packaging, or router access occurred.

Phase 38 keeps the complete Phase 37 build correction and replaces the
single HTTP/2 transfer with a resumable HTTP/1.1 downloader and a
resumable wget fallback.

## Safety boundary

The workflow may produce only a review-only SquashFS rootfs component.
It blocks Qualcomm UBI packaging and does not create a boot-approved
RA72 image. It never contacts the router or changes SSH, UART, NAND,
bootloader variables, or partitions.
