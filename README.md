# DD-WRT RA72 Phase 37

Phase 37 corrects the native DD-WRT userspace/rootfs build environment
identified by the Phase 36 logs.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## What Phase 37 changes

- Downloads the official DD-WRT toolchain archive on the temporary
  GitHub Ubuntu runner.
- Selects and tests the native `aarch64-linux-uclibc` compiler before
  starting the large source build.
- Exports the required DD-WRT `linux-6.12-nss` tree and passes its exact
  path to `Makefile.ipq60xx`.
- Selects the non-preflash MX4200 IPQ60xx configuration as the nearest
  existing DD-WRT userspace build baseline.
- Creates the missing `src/opt` build directory.
- Adds `-fcommon` only to the host DD-WRT configuration utility to
  resolve the modern-GCC `current_menu` link failure.
- Executes the native DD-WRT rootfs target and validates
  `root.ipq5018` if it is produced.
- Uploads complete diagnostics even if the build fails.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 37: Build DD-WRT RA72 rootfs with native uClibc`

6. Press **Run workflow**.
7. Leave all three fields unchanged and confirm the run.

The official toolchain archive is about 4.1 GB. Download, source export,
and compilation can take one to several hours. A red result still uploads
the diagnostic artifact.

Download this artifact when the run stops:

`ddwrt-ra72-phase37-native-uclibc-rootfs-build`

Send back:

- `REPORT-PHASE37.txt`
- `review/phase37-status.txt`
- `review/selected-toolchain-contract.txt`
- `review/toolchain-test-status.txt`
- `review/userspace-build-status.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/source-summary.txt`
- `review/phase37-integration-checks.txt` if present

## Safety

This phase does not access the router and does not build an approved
flashable image. Qualcomm UBI packaging is deliberately disabled.
Any rootfs produced is a review-only component and must not be booted or
flashed.
