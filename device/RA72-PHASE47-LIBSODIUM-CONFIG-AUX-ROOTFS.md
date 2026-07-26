# RA72 Phase 47 libsodium config-helper rootfs build

## Exact target

- Product: Xiaomi **Mi AIoT AX6000**
- Model: **RA72**
- SoC: Qualcomm **IPQ5018**
- Board family: **MP03.1**

This is not Xiaomi Mi Router AX6000 (IPQ8072A) and not Redmi AX6000
(MT7986).

## Phase 46 evidence

The source was pinned to public DD-WRT SVN revision `65774`. The four
required revision headers were generated from that verified value and
matched byte-for-byte. Native configuration advanced beyond the former
`revision.h` blocker.

The Phase 46 PCRE library-only contract passed: `libpcre`,
`libpcreposix`, and `libpcrecpp` were built and the three cross-target
unit tests were not requested. The configure stage advanced to
libsodium and stopped because `build-aux/config.sub`, replaced by
libsodium's `autogen.sh`, was not executable by the configure script.

## Phase 47 libsodium contract

Phase 47 preserves the verified PCRE correction and changes only the
libsodium configure chain. After `autogen.sh`, it installs Ubuntu
`autotools-dev` copies of:

- `build-aux/config.guess`
- `build-aux/config.sub`

The script requires exactly one sodium recipe change. It verifies both
host files, preserves their SHA-256 hashes, ensures both generated
libsodium helpers are executable, runs `config.guess`, and validates
the AArch64 uClibc triplet through `config.sub`. Original and patched
sodium rules, a unified diff, command outputs, and validation results
are retained in the artifact.

## Continued build contract

After the PCRE contract passes, the workflow continues the native
DD-WRT configure, sequential prerequisite build, full userspace
compile, install, and SquashFS rootfs discovery using the verified
RA72 ATH11K profile.

## Safety boundary

At most, the workflow may produce a review-only SquashFS rootfs
component. Qualcomm UBI packaging remains disabled. The workflow never
contacts the router or changes SSH, UART, NAND, boot variables, or
partitions.
