# RA72 Phase 50 ncurses-preconfigure rootfs build

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

## Phase 48 verified result

The official DD-WRT toolchain archive downloaded and validated
successfully. The source export, PCRE production-library contract, and
all libsodium configuration-helper checks passed.

Configuration progressed into `dnscrypt` and its nested `autoreconf`
failed because `/usr/share/aclocal/ltdl.m4` was absent.

## Phase 49 verified result

The Ubuntu runner explicitly installs `libltdl-dev`. Before any large
download or source export, the script verifies that
`/usr/share/aclocal/ltdl.m4` exists and is readable, then records its
package provider and SHA-256 hash. The workflow stops immediately with
a dedicated status if this prerequisite is missing.

That contract passed. Configuration progressed beyond `dnscrypt`, then
`make -C ncurses` failed because `src/router/ncurses/Makefile` did not
exist.

## Phase 50 ncurses contract

The script saves DD-WRT's exact `rules/ncurses.mk`, verifies the native
`ncurses-configure` target, and runs that target before the full
configure stage. It will continue only when the focused command exits
successfully and creates `src/router/ncurses/Makefile`.

The artifact retains the focused command, exit status, before/after
inventory, Makefile hash, complete focused log, and final 500 log lines.
If the target is absent or the Makefile is not generated, the workflow
stops with a dedicated Phase 50 status.

## Preserved contracts

Phase 50 preserves the resumable toolchain downloader, verified PCRE
correction, libsodium configure chain, and the passed libltdl contract.
After libsodium `autogen.sh`, it still installs Ubuntu `autotools-dev`
copies of:

- `build-aux/config.guess`
- `build-aux/config.sub`

The script requires exactly one sodium recipe change. It verifies both
host files, preserves their SHA-256 hashes, ensures both generated
libsodium helpers are executable, runs `config.guess`, and validates
the AArch64 uClibc triplet through `config.sub`. Original and patched
sodium rules, a unified diff, command outputs, and validation results
are retained in the artifact.

## Continued build contract

After the ncurses preconfigure contract passes, the workflow continues
the native DD-WRT configure, sequential prerequisite build, full
userspace compile, install, and SquashFS rootfs discovery using the
verified RA72 ATH11K profile.

## Safety boundary

At most, the workflow may produce a review-only SquashFS rootfs
component. Qualcomm UBI packaging remains disabled. The workflow never
contacts the router or changes SSH, UART, NAND, boot variables, or
partitions.
