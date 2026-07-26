# RA72 Phase 44 wireless profile and rootfs build

## Exact target

- Product: Xiaomi **Mi AIoT AX6000**
- Model: **RA72**
- SoC: Qualcomm **IPQ5018**
- Board family: **MP03.1**

This target must not be confused with Xiaomi Mi Router AX6000
(IPQ8072A) or Redmi AX6000 (MT7986).

## Corrected source contract

The native `Makefile.ipq60xx` uses both repository-level paths and
paths below `src/router`. Phase 44 therefore exports the public
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

## Wireless-profile correction

Phase 43 fixed the missing `typedefs.h` source tree and progressed
through Jansson, wireless-tools, and most of libutils. It then exposed
an incompatible setting inherited from the nearest IPQ6018 profile:
`CONFIG_MADWIFI=y`. That legacy driver selection requires
`register/register_check.o`, which is absent from public source and is
not the RA72 radio stack.

Phase 44:

1. retains the unmodified native IPQ6018 configuration for review;
2. enables `CONFIG_ATH11K=y`;
3. disables MADWIFI, ATH9K, ATH10K, REGISTER, SUPERCHANNEL, and legacy
   QCA98xx device selections;
4. verifies the final profile before compilation;
5. records the exact configuration diff;
6. resumes configure, bootstrap, `all`, and `install`.

No missing registration object, source file, or package Makefile is
fabricated by this project.

## Safety boundary

The workflow may produce only a review-only SquashFS rootfs component.
Qualcomm UBI packaging remains disabled. It never contacts the router or
changes SSH, UART, NAND, boot variables, or partitions.
