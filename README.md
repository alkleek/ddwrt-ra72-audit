# DD-WRT RA72 Phase 42

Phase 42 resolves the native package-configuration blocker found after
Phase 41 corrected the source layout and reached real DD-WRT package
compilation.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 41 result

The official AArch64 uClibc-compatible toolchain passed its ARM64
compile test. The corrected `opt`, `tools`, and early kernel
configuration contracts all passed. The build then successfully built
`nvram`, `wireless-tools`, and `libnl-tiny` before stopping at:

`make -C jansson`

The `jansson` source directory existed, but its generated `Makefile`
did not, proving that the native DD-WRT configure stage must run before
the `all` stage.

## Phase 42 corrections

- Preserves all source and toolchain corrections from Phase 41.
- Runs the native `Makefile.ipq60xx configure` stage first.
- Verifies that the real `jansson/Makefile` was generated.
- Uses `jansson-configure` only as a native fallback if needed.
- Sequentially bootstraps `nvram`, `jansson`, and `utils`.
- Runs the native compile stage and then the native install/rootfs stage.
- Captures complete configure, bootstrap, and userspace logs.
- Correctly inventories `opt` without following its intentionally
  unresolved firmware-only symlinks.
- Searches verified SquashFS candidates named `root.ipq5018`,
  `root.ipq60xx`, or `root.fs`.
- Keeps every Qualcomm UBI/flash packaging path disabled.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 42: Resolve configure and bootstrap DD-WRT RA72 rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase42-configure-bootstrap-rootfs-build`

Send back the complete downloaded artifact ZIP. The most useful files
inside it are:

- `REPORT-PHASE42.txt`
- `review/phase42-status.txt`
- `review/source-layout-contract.txt`
- `review/configure-stage-status.txt`
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
- `review/phase42-integration-checks.txt` if present

## Safety

This workflow never contacts the router. It does not produce an
approved firmware image. Any rootfs is a review-only component and must
not be booted or flashed.
