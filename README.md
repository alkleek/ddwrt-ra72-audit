# DD-WRT RA72 Phase 64

Phase 63 proved that the staged util-linux `blkid.pc` and `uuid.pc` contract
is valid. The AArch64 uClibc link test passed, and the native DD-WRT configure
stage detected blkid. The first real later blocker was:

`Package 'libudev', required by 'virtual:world', not found`

Phase 64 supplies only the missing pkg-config description for DD-WRT's own
in-tree libudev and resumes the review-only userspace/rootfs build. It does
not replace libudev, import OpenWrt code, or build approved firmware.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 64 correction

The workflow:

1. pins public DD-WRT source revision `65793` and retains all earlier verified
   corrections;
2. repeats the focused util-linux build and verifies the staged blkid/uuid
   metadata and AArch64 uClibc link proof;
3. locates DD-WRT's own in-tree `libudev.h`;
4. creates an isolated `libudev.pc` whose include and library paths point only
   to that same DD-WRT source tree;
5. verifies `pkg-config --exists blkid uuid libudev`, plus the exact libudev
   include path, library path and `-ludev` flag;
6. accepts the generated e2fsprogs MCONFIG only when it matches either the
   verified private-library layout or the actual external util-linux
   blkid/uuid layout;
7. requires btrfsprogs configure to detect both blkid and libudev before
   classifying any later blocker.

No router is accessed. No bootloader, NAND partition, UBI volume, boot
variable, DTB, wireless profile, or image recipe is changed.

## Upload and run

1. Upload the contents of this update over the existing
   `ddwrt-ra72-audit` repository.
2. Preserve every folder path, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 64: Stage libudev pkg-config and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and start the run.

After the run stops, download:

`ddwrt-ra72-phase64-libudev-pkgconfig-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE64.txt`
- `review/phase64-status.txt`
- `review/btrfs-libudev.pc.staged`
- `review/btrfs-libudev-pkgconfig-generation-contract.txt`
- `review/btrfs-libudev-pkgconfig-contract.txt`
- `review/btrfs-blkid-pkgconfig-query.txt`
- `review/btrfs-blkid-pkgconfig-contract.txt`
- `review/btrfs-blkid-configure-contract.txt`
- `review/e2fsprogs-private-blkid-generated-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase64-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file, if any, is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 64 file.
