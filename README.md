# DD-WRT source audit for Xiaomi Mi AIoT AX6000 RA72

This is **phase 1 only** of a private DD-WRT port investigation.

It runs manually on a GitHub-hosted Ubuntu runner and checks the public DD-WRT
source inventory for an existing Qualcomm IPQ5018/IPQ50xx platform foundation.

It does not:

- build firmware;
- modify a router;
- claim DD-WRT compatibility;
- produce anything safe to flash.

## Exact device

Only the Xiaomi **Mi AIoT AX6000**, model **RA72**, based on Qualcomm IPQ5018
and board configuration MP03.1 is in scope.

It is not for the Xiaomi Mi Router AX6000 or Redmi AX6000.

## Run

1. Upload this project to a new GitHub repository.
2. Open **Actions**.
3. Select **Audit DD-WRT source for Xiaomi Mi AIoT AX6000 RA72**.
4. Select **Run workflow**.
5. Download the artifact named `ddwrt-ra72-source-audit`.

Do not perform any operation on a router during this phase.

## Phase 2

Phase 2 checks whether the public tree contains a real DD-WRT IPQ5018
build/profile foundation rather than kernel drivers alone. Run:

`Audit DD-WRT IPQ5018 build foundation for RA72`

Its artifact is named `ddwrt-ra72-phase2-audit`. It is text-only and is not
firmware.

## Phase 3

Phase 3 inspects DD-WRT configuration, rules, and device initialization files
to locate the closest Qualcomm ARM64 build template for a new RA72 target. Run:

`Audit DD-WRT build system for a new RA72 target`

Its artifact is named `ddwrt-ra72-phase3-audit`. It contains reports and public
source excerpts only; it is not firmware.

## Phase 4

Phase 4 inspects the concrete IPQ5018 templates found in phase 3, especially
the Linksys MR5500 and MX5500. Run:

`Audit DD-WRT IPQ5018 templates for RA72`

Its artifact is named `ddwrt-ra72-phase4-audit`. It collects the relevant
public source excerpts needed to compare image construction, board detection,
flash layout, networking, Wi-Fi calibration, and MAC handling with RA72. It
does not build firmware.

## Phase 5

Phase 5 compares the working OpenWrt definition for the exact Xiaomi Mi AIoT
AX6000 RA72 with the DD-WRT IPQ5018 reference devices. Run:

`Compare DD-WRT templates with Xiaomi Mi AIoT AX6000 RA72`

Keep the default OpenWrt reference unless deliberately auditing another known
working revision. Its artifact is named `ddwrt-ra72-phase5-port-map`. It maps
device identity, DTS, NAND/A-B layout, Ethernet, Wi-Fi calibration, MAC
handling, LEDs, and buttons. It remains audit-only and creates no firmware.

## Phase 6

Phase 6 audits the exact RA72 NAND layout, Xiaomi A/B boot flags, image-size
constraints, and the closest DD-WRT image/build references. Run:

`Audit RA72 NAND and A-B boot safety for DD-WRT`

Its artifact is named `ddwrt-ra72-phase6-nand-boot-audit`. It does not build
firmware and must not be flashed.

## Phase 7

Phase 7 defines the safety contract for a future RAM-only boot prototype and
lists the exact read-only UART bootloader information still required. Run:

`Define safe boot-only DD-WRT prototype contract for RA72`

Its artifact is named `ddwrt-ra72-phase7-boot-contract`. It does not build
firmware and must not be flashed.

## Phase 8

Phase 8 validates a sanitized hardware contract derived from the live Device
Tree of the working OpenWrt installation. The raw DTB is not stored because it
may contain device-specific values. Run:

`Validate running RA72 DTB contract for DD-WRT port`

Its artifact is named `ddwrt-ra72-phase8-runtime-dtb-contract`. It contains the
verified identity, memory reservations, Ethernet, Wi-Fi calibration, NAND and
GPIO contract plus a non-flashable DD-WRT port checklist. It builds no firmware
and makes no changes to the router. The RAM-only prototype remains blocked
until a bootloader-safe load address and image container are verified.

## Phase 9

Phase 9 creates the first reviewable source-port draft for the exact Xiaomi Mi
AIoT AX6000 RA72. It stages the working OpenWrt RA72 DTS against DD-WRT's
IPQ5018 kernel references, verifies the essential hardware nodes, reports
incompatible include dependencies, and emits a draft source patch.

Run:

`Generate first DD-WRT RA72 source-port draft`

Its artifact is named `ddwrt-ra72-phase9-source-port-draft`. It contains source
text and reports only. It does not compile a kernel, create an initramfs, build
firmware, or authorize booting/flashing.

## Phase 10

Phase 10 adapts the three generic Linux Device Tree binding headers identified
in Phase 9 and attempts to preprocess, compile, and decompile the RA72 DTS
inside a temporary DD-WRT IPQ5018 compatibility tree.

Run:

`Compile review-only DD-WRT RA72 Device Tree draft`

Its artifact is named `ddwrt-ra72-phase10-dts-compile-audit`. Review
`REPORT-PHASE10.txt`, `review/compile-status.tsv`, the compiler logs, binding
provenance, and compiled-tree verification. A generated DTB is a compiler test
object only. It is not firmware and must never be booted, flashed, installed,
TFTP-loaded, or written to a router.
## Phase 11

Phase 11 fixes the precise missing include discovered by Phase 10:
`dt-bindings/input/linux-event-codes.h`. It then repeats the review-only
preprocessor, compiler, decompiler, and RA72 identity checks.

Version 0.11.2 also materializes the real Linux
`include/uapi/linux/input-event-codes.h` target. This avoids passing the
one-line text of a relative symlink to `dtc`.

Version 0.11.3 removes, from the compiler-test copy only, the optional
OpenWrt-only `&ge_phy` overlay discovered by the previous Phase 11 run.
DD-WRT's public IPQ5018 tree has no `ge_phy` label. The removal is recorded in
`review/source-adaptations.txt`; it is not a claim that the Ethernet PHY is
supported or operational.

Run **Fix includes and compile review-only DD-WRT RA72 Device Tree**. Its
artifact is named `ddwrt-ra72-phase11-dts-compile-fix`. This remains a
source/compiler audit; it produces no firmware that is safe to boot or flash.
