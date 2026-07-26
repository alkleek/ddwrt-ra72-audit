# RA72 Phase 43 DD-WRT header-tree and rootfs build

## Exact target

- Product: Xiaomi **Mi AIoT AX6000**
- Model: **RA72**
- SoC: Qualcomm **IPQ5018**
- Board family: **MP03.1**

This target must not be confused with Xiaomi Mi Router AX6000
(IPQ8072A) or Redmi AX6000 (MT7986).

## Corrected source contract

The native `Makefile.ipq60xx` uses both repository-level paths and
paths below `src/router`. Phase 43 therefore exports the public
repository's `opt`, `tools`, and canonical `src/include.v24` trees in
addition to `src/router` and `src/linux/universal/linux-6.12-nss`.
Optional historical header trees are exported only when they exist.

The workflow records whether `src/router/opt` arrived as a source
symlink or needed the relative source-layout link expected by the
Makefile. It verifies actual `.webconfig` files before starting a
build; no empty or fabricated web configuration is accepted.

The kernel's native `.config_ipq6018` is copied to `.config` before
userspace dependency parsing because several early rules inspect the
kernel configuration before the later kernel target performs that copy.

## Header-tree correction

Phase 42 proved that native configure generates and builds Jansson. It
then stopped in `libutils` because `shared/utils.h` includes
`typedefs.h`, while the canonical public `src/include.v24` tree had not
been exported.

Phase 43:

1. exports `src/include.v24` at the same pinned source revision;
2. locates the real `typedefs.h`;
3. tests it with the selected AArch64 uClibc compiler;
4. records the native include contract;
5. resumes configure, bootstrap, `all`, and `install`.

No source header or generated package Makefile is fabricated by this
project.

## Safety boundary

The workflow may produce only a review-only SquashFS rootfs component.
Qualcomm UBI packaging remains disabled. It never contacts the router or
changes SSH, UART, NAND, boot variables, or partitions.
