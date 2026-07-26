# DD-WRT RA72 Phase 35

Phase 34 successfully created and verified the review-only RA72 FIT kernel
container. Phase 35 now performs the first accelerated native DD-WRT
userspace/rootfs build attempt.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## What is accelerated

One workflow run now performs source pinning, source export, native target
discovery, toolchain-contract capture, an actual userspace build,
`root.ipq5018` discovery, SquashFS extraction, web-interface checks, ARM64
checks, and automatic failure classification.

If it is blocked, the resulting artifact should tell us the exact next fix
without adding several separate audit phases.

## Safety

The workflow never contacts the router. UBI/final-firmware packaging is
disabled. A rootfs produced by this phase is only a review component and
must not be booted or flashed.

## Upload

Upload the contents of this update over the existing GitHub project. Keep
the folders exactly as provided, including `.github`.

## Run

In GitHub **Actions**, select:

`Phase 35: Build DD-WRT RA72 userspace rootfs`

Press **Run workflow** and leave both fields unchanged.

This is a large source and userspace build. It may run for one to several
hours. A red result is still useful because the artifact is uploaded
unconditionally.

Download the artifact:

`ddwrt-ra72-phase35-userspace-rootfs-build`

Send back:

- `REPORT-PHASE35.txt`
- `review/phase35-status.txt`
- `review/userspace-build-status.txt`
- `review/build-failure-classification.txt`
- `review/userspace-build-tail.txt`
- `review/userspace-toolchain-contract.txt`
- `review/make-targets.txt`
- `review/selected-make-target.txt`
- `review/source-summary.txt`
- `review/phase35-integration-checks.txt` if present
- `review/rootfs-superblock.txt` if present
- `review/rootfs-busybox-type.txt` if present

Do not boot or flash any Phase 35 output.
