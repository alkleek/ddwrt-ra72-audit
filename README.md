# DD-WRT RA72 Phase 63

Phase 62 successfully staged the generated util-linux `blkid.pc` and
`uuid.pc`, resolved `pkg-config --static --libs blkid`, and linked the
AArch64 uClibc blkid test program. It stopped only because the local Phase 62
diagnostic incorrectly required `-luuid` in blkid's static flags.

The generated DD-WRT metadata does not declare UUID as a private dependency of
blkid, and the verified link succeeds without it. Phase 63 therefore preserves
the generated package contract instead of inventing an extra dependency. It
verifies that the resolved flags match exactly what the generated `blkid.pc`
declares, then resumes the review-only rootfs build.

This phase does not produce approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 63 correction

The workflow:

1. pins public DD-WRT source revision `65793` and retains all earlier verified
   corrections;
2. completes the focused util-linux cross-build and unprivileged staged
   install;
3. requires the staged target files:
   - `usr/tmp/pkgconfig/blkid.pc`
   - `usr/tmp/pkgconfig/uuid.pc`
   - `usr/tmp/libblkid.a`
   - `usr/tmp/libuuid.a`
4. copies only the two generated `.pc` files into an isolated Phase 63
   pkg-config directory;
5. rewrites their install prefixes to absolute paths inside the temporary
   staged util-linux tree without changing their package fields or
   dependencies;
6. prepends that isolated directory to `PKG_CONFIG_PATH`;
7. requires `pkg-config --static --libs blkid` to include `-lblkid`, use the
   staged target library path, and include or omit `-luuid` exactly as declared
   by the generated source metadata;
8. cross-links a small AArch64 uClibc blkid program before starting the long
   native DD-WRT configure stage;
9. proves the earlier btrfsprogs static-description error is absent before
   accepting any later blocker or rootfs result.

No router is accessed. No bootloader, NAND partition, UBI volume, or boot
variable is changed.

## Upload and run

1. Upload the contents of this update over the existing
   `ddwrt-ra72-audit` repository.
2. Preserve every folder path, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 63: Accept verified blkid pkg-config and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and start the run.

After the run stops, download:

`ddwrt-ra72-phase63-verified-blkid-pkgconfig-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE63.txt`
- `review/phase63-status.txt`
- `review/btrfs-blkid.pc.original`
- `review/btrfs-uuid.pc.original`
- `review/btrfs-blkid.pc.rewritten`
- `review/btrfs-uuid.pc.rewritten`
- `review/btrfs-blkid-pkgconfig-rewrite-contract.txt`
- `review/btrfs-blkid-pkgconfig-query.txt`
- `review/btrfs-blkid-pkgconfig-contract.txt`
- `review/btrfs-blkid-static-link.log`
- `review/btrfs-blkid-static-link-file.txt`
- `review/btrfs-blkid-configure-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase63-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file, if any, is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 63 file.
