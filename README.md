# DD-WRT RA72 Phase 43

Phase 43 restores the canonical DD-WRT header tree required by the
native IPQ60xx userspace build, then resumes the configure, bootstrap,
compile, and rootfs stages.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 42 result

The official AArch64 uClibc-compatible toolchain passed its ARM64
compile test. The corrected source layout and early kernel configuration
contracts passed. The native configure stage generated the real
`jansson/Makefile`, and Jansson compiled successfully. The configure
stage then reached `libutils` and stopped at:

`fatal error: typedefs.h: No such file or directory`

This identifies a missing DD-WRT source export rather than a Jansson or
toolchain failure. The header is supplied by the public
`src/include.v24` tree used by DD-WRT's router build.

## Phase 43 corrections

- Preserves every verified Phase 42 source and toolchain correction.
- Exports canonical public `src/include.v24` at the same pinned SVN
  revision as all other DD-WRT sources.
- Requires a real `typedefs.h`; no generated or fabricated replacement
  header is permitted.
- Preprocesses `typedefs.h` with the selected DD-WRT AArch64 uClibc
  compiler before the native build starts.
- Records the exact header consumers and include-path contract.
- Runs native configure, sequential bootstrap, compile, and install.
- Classifies configure failures separately and retains the first useful
  error lines if another dependency is uncovered.
- Searches only verified SquashFS rootfs candidates.
- Keeps every Qualcomm UBI/flash packaging path disabled.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 43: Restore DD-WRT headers and build RA72 rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase43-ddwrt-header-tree-rootfs-build`

Send back the complete downloaded artifact ZIP. The most useful files
inside it are:

- `REPORT-PHASE43.txt`
- `review/phase43-status.txt`
- `review/ddwrt-header-tree-contract.txt`
- `review/typedefs-header-candidates.txt`
- `review/typedefs-preprocess.log`
- `review/header-include-contract.txt`
- `review/source-layout-contract.txt`
- `review/configure-stage-status.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/bootstrap-stage-status.txt`
- `review/ddwrt-bootstrap-build-tail.txt`
- `review/jansson-rule.mk`
- `review/jansson-before-configure.txt`
- `review/jansson-after-configure.txt`
- `review/userspace-build-status.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase43-integration-checks.txt` if present

## Safety

This workflow never contacts the router. It does not produce an
approved firmware image. Any rootfs is a review-only component and must
not be booted or flashed.
