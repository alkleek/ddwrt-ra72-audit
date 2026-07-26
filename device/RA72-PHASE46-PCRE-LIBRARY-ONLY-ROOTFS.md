# RA72 Phase 46 PCRE library-only rootfs build

## Exact target

- Product: Xiaomi **Mi AIoT AX6000**
- Model: **RA72**
- SoC: Qualcomm **IPQ5018**
- Board family: **MP03.1**

This is not Xiaomi Mi Router AX6000 (IPQ8072A) and not Redmi AX6000
(MT7986).

## Phase 45 evidence

The source was pinned to public DD-WRT SVN revision `65774`. The four
required revision headers were generated from that verified value and
matched byte-for-byte. Native configuration advanced beyond the former
`revision.h` blocker.

PCRE 8.41 produced all three required libraries, but its default `all`
target also attempted to link three target-architecture unit tests.
Those tests failed because the cross linker did not resolve
`libpcre.so.1` as an indirect dependency of `libpcrecpp.so`.

## Phase 46 PCRE contract

Phase 46 changes only the native `pcre` recipe so it builds:

- `libpcre.la`
- `libpcreposix.la`
- `libpcrecpp.la`

It excludes only:

- `pcrecpp_unittest`
- `pcre_scanner_unittest`
- `pcre_stringpiece_unittest`

The script requires exactly one recipe change and verifies the three
shared libraries after configuration. Original rule, patched rule,
unified diff, selected targets, library list, and validation results
are retained in the artifact.

No PCRE production-library feature is disabled. Nonlibrary PCRE
programs are not requested during this cross-compiled prerequisite;
the three targets that actually blocked Phase 45 are recorded
explicitly in the artifact.

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
