# RA72 Phase 42 configure/bootstrap and rootfs build

## Exact target

- Product: Xiaomi **Mi AIoT AX6000**
- Model: **RA72**
- SoC: Qualcomm **IPQ5018**
- Board family: **MP03.1**

This target must not be confused with Xiaomi Mi Router AX6000
(IPQ8072A) or Redmi AX6000 (MT7986).

## Corrected source contract

The native `Makefile.ipq60xx` uses both repository-level paths and
paths below `src/router`. Phase 42 therefore exports the public
repository's `opt` and `tools` trees in addition to `src/router`,
`src/linux/universal/linux-6.12-nss`, `src/include`, and `src/shared`.

The workflow records whether `src/router/opt` arrived as a source
symlink or needed the relative source-layout link expected by the
Makefile. It verifies actual `.webconfig` files before starting a
build; no empty or fabricated web configuration is accepted.

The kernel's native `.config_ipq6018` is copied to `.config` before
userspace dependency parsing because several early rules inspect the
kernel configuration before the later kernel target performs that copy.

## Native configure and bootstrap contract

Phase 41 reached real compilation but stopped because `jansson/Makefile`
had not yet been generated. Phase 42 now follows the native DD-WRT
sequence:

1. run `Makefile.ipq60xx configure`;
2. verify the generated Jansson Makefile;
3. bootstrap `nvram`, `jansson`, and `utils` sequentially;
4. run the normal `all` and `install` stages.

No Jansson source or Makefile is fabricated by this project.

## Safety boundary

The workflow may produce only a review-only SquashFS rootfs component.
Qualcomm UBI packaging remains disabled. It never contacts the router or
changes SSH, UART, NAND, boot variables, or partitions.
