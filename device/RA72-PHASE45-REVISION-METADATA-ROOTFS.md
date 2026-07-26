# RA72 Phase 45 verified revision metadata and rootfs build

## Exact target

- Product: Xiaomi **Mi AIoT AX6000**
- Model: **RA72**
- SoC: Qualcomm **IPQ5018**
- Board family: **MP03.1**

This target must not be confused with Xiaomi Mi Router AX6000
(IPQ8072A) or Redmi AX6000 (MT7986).

## Verified Phase 44 progress

Phase 44 removed the public-source-incompatible legacy wireless profile.
`CONFIG_ATH11K=y` remained enabled for RA72 while MADWIFI, ATH9K,
ATH10K, REGISTER, SUPERCHANNEL, and legacy QCA98xx selections were
disabled. The previous request for `register/register_check.o` no
longer occurred.

The native configure stage compiled Jansson and wireless-tools and
entered `libutils`. Compilation stopped only because
`libutils/utils.c` includes the generated file `revision.h`.

## Revision metadata contract

The source tree is exported at a revision returned by:

`svn info --show-item revision`

Phase 45 uses that already verified value to create exactly:

`#define SVN_REVISION "<verified revision>"`

The header is placed in the native DD-WRT consumer directories:

- `src/router/libutils`
- `src/router/shared`
- `src/router/httpd`
- `src/router/httpd/visuals`

All four files must match the expected one-line template byte-for-byte.
Their paths, direct source consumers, hashes, and the pinned revision
are recorded in the artifact. A missing destination or any mismatch
stops the workflow before compilation.

This is generated version metadata required by DD-WRT. It is not a
replacement for proprietary wireless source and it does not modify the
RA72 kernel or device tree.

## Continued build contract

After validating revision metadata, the workflow keeps the Phase 44
RA72 ATH11K userspace profile and runs the native DD-WRT configure,
sequential prerequisite build, full userspace compile, install, and
SquashFS rootfs discovery.

## Safety boundary

The workflow may produce only a review-only SquashFS rootfs component.
Qualcomm UBI packaging remains disabled. It never contacts the router or
changes SSH, UART, NAND, boot variables, or partitions.
