# RA72 Phase 35 userspace/rootfs build contract

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not Xiaomi Mi Router AX6000 (IPQ8072A) and not Redmi AX6000.

## Purpose

Phase 35 is the first accelerated DD-WRT userspace and root-filesystem build
attempt. In one workflow run it:

1. pins the public DD-WRT SVN revision;
2. exports the complete `src/router` build domain;
3. exports the IPQ5018 Linux tree and available shared source domains;
4. records the IPQ60xx configuration and toolchain contract;
5. discovers the native make target;
6. invokes the native `Makefile.ipq60xx` build;
7. searches for `root.ipq5018`;
8. validates SquashFS structure, DD-WRT web files, init, shell, and ARM64
   userspace when a rootfs is produced;
9. classifies the first blocker when the build cannot produce a rootfs.

This deliberately combines discovery, build, and validation instead of
splitting them into several small audit phases.

## Safety boundary

The workflow never contacts the router. It does not use SSH, UART, U-Boot,
NAND, MTD, boot variables, or Xiaomi partitions.

Qualcomm UBI packaging is disabled during this phase. A valid
`root.ipq5018`, if produced, is copied as a review-only component. It is not
complete firmware and must not be booted or flashed.

## Exit states

- `RA72_DDWRT_USERSPACE_ROOTFS_BUILD_PASS_REVIEW_ONLY`
- `BLOCKED_DDWRT_ROUTER_SOURCE_EXPORT_FAILED`
- `BLOCKED_DDWRT_USERSPACE_BUILD_FAILED`
- `BLOCKED_DDWRT_ROOTFS_NOT_PRODUCED`
- `BLOCKED_DDWRT_ROOTFS_VALIDATION_FAILED`
- `BLOCKED_UNEXPECTED_ERROR`

Blocked runs are useful: the artifact includes the exact source revision,
toolchain expectations, selected make target, build tail, and automatic
failure classification for the next correction.
