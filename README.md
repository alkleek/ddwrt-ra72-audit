# DD-WRT RA72 Phase 38

Phase 38 resumes the native DD-WRT userspace/rootfs build after Phase 37
was interrupted while downloading the official 4.1 GB toolchain archive.
The build itself did not start in Phase 37.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Download correction

Phase 37 stopped on:

`curl: (92) HTTP/2 stream 1 was not closed cleanly`

Phase 38:

- forces HTTP/1.1 instead of HTTP/2;
- retains and resumes the partially downloaded archive;
- retries transient errors automatically;
- performs six resumable curl rounds;
- falls back to resumable `wget` if curl cannot finish;
- records every attempt and partial byte count in the review artifact.

## Other build corrections retained

- Uses and tests the official `aarch64-linux-uclibc` compiler.
- Exports the DD-WRT `linux-6.12-nss` source tree.
- Selects the non-preflash MX4200 IPQ60xx userspace configuration as
  the closest existing DD-WRT baseline.
- Creates the missing `src/opt` directory.
- Adds `-fcommon` only to the host DD-WRT configuration utility.
- Validates `root.ipq5018` if the native build produces it.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 38: Build DD-WRT RA72 rootfs with resumable uClibc`

6. Press **Run workflow**.
7. Leave all three fields unchanged and confirm the run.

Download this artifact when the run stops:

`ddwrt-ra72-phase38-resumable-uclibc-rootfs-build`

Send back:

- `REPORT-PHASE38.txt`
- `review/phase38-status.txt`
- `review/toolchain-download-attempts.txt`
- `review/selected-toolchain-contract.txt` if present
- `review/toolchain-test-status.txt` if present
- `review/userspace-build-status.txt` if present
- `review/build-failure-classification.txt` if present
- `review/first-build-errors.txt` if present
- `review/userspace-build-tail.txt` if present
- `review/phase38-integration-checks.txt` if present

## Safety

This phase does not access the router and does not build an approved
flashable image. Qualcomm UBI packaging is deliberately disabled.
Any rootfs produced is a review-only component and must not be booted or
flashed.
