# DD-WRT RA72 Phase 40

Phase 40 corrects the selective extraction of the official DD-WRT
AArch64 toolchain and then continues into the native userspace/rootfs
build.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 39 result

Phase 39 successfully:

- downloaded the complete official toolchain archive using aria2;
- indexed the valid XZ/TAR archive;
- found the current Cortex-A53 AArch64 toolchain;
- found its compatibility command
  `aarch64-linux-uclibc-gcc`.

It stopped because passing thousands of indexed member names back to
`tar -T` did not match the archive's internal path normalization.
The DD-WRT source build had not started.

## Phase 40 correction

- Keeps the segmented aria2 download.
- Selects the same verified toolchain root.
- Extracts that root as one recursive wildcard tree.
- Matches the root regardless of an internal leading path prefix.
- Captures only the final 500 extraction log lines on failure.
- Tests the compiler before exporting and building DD-WRT.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 40: Extract toolchain and build DD-WRT RA72 rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase40-toolchain-extraction-rootfs-build`

Send back:

- `REPORT-PHASE40.txt`
- `review/phase40-status.txt`
- `review/toolchain-extraction-tail.txt`
- `review/selected-toolchain-contract.txt` if present
- `review/toolchain-test-status.txt` if present
- `review/userspace-build-status.txt` if present
- `review/build-failure-classification.txt` if present
- `review/first-build-errors.txt` if present
- `review/userspace-build-tail.txt` if present
- `review/phase40-integration-checks.txt` if present

## Safety

This phase does not access the router and does not build an approved
flashable image. Qualcomm UBI packaging is deliberately disabled.
Any rootfs produced is a review-only component and must not be booted or
flashed.
