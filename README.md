# DD-WRT RA72 Phase 39

Phase 39 replaces the long single-stream toolchain download with a
segmented and automatically resumed download.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 38 finding

The official DD-WRT server repeatedly closed each long transfer after a
small portion. Phase 38 proved that byte-range resume works and reached
about 435 MB, but one curl/wget connection was not sufficient to finish
the 4.1 GB archive. The DD-WRT source build did not start.

## Phase 39 correction

- Uses `aria2c` with eight parallel range connections.
- Divides the official archive into 4 MB pieces.
- Retries and resumes individual pieces without restarting the archive.
- Uses one bounded 180-minute download session.
- Writes quiet one-minute summaries instead of thousands of progress
  lines.
- Verifies the completed archive before selecting and testing the native
  `aarch64-linux-uclibc` compiler.

All Phase 37 build-environment corrections remain included.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 39: Build DD-WRT RA72 rootfs with segmented uClibc`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase39-segmented-uclibc-rootfs-build`

Send back:

- `REPORT-PHASE39.txt`
- `review/phase39-status.txt`
- `review/toolchain-download-tail.txt`
- `review/toolchain-archive-size.txt` if present
- `review/selected-toolchain-contract.txt` if present
- `review/toolchain-test-status.txt` if present
- `review/userspace-build-status.txt` if present
- `review/build-failure-classification.txt` if present
- `review/first-build-errors.txt` if present
- `review/userspace-build-tail.txt` if present
- `review/phase39-integration-checks.txt` if present

## Safety

This phase does not access the router and does not build an approved
flashable image. Qualcomm UBI packaging is deliberately disabled.
Any rootfs produced is a review-only component and must not be booted or
flashed.
