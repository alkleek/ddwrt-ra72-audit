# DD-WRT RA72 Phase 57

Phase 56 stopped safely before compilation because it expected a
generated util-linux file at:

```text
src/router/util-linux/libblkid/src/blkid.h
```

At this point in the pinned source export, the authoritative public
header is still a source template such as `blkid.h.in`; the generated
`blkid.h` does not exist until util-linux is configured. The legacy
e2fsprogs `dev.c` is present, so the earlier compiler diagnosis remains
valid, but Phase 56 could not verify its public-header side.

Phase 57 removes the fragile single-file assumption. It searches only
inside the pinned util-linux source for `blkid.h` and `blkid.h.in`,
selects a candidate only when its exact `blkid_dev_set_search`
prototype has both `const char *` parameters, records the candidate
inventory and selected path, then applies the same narrow correction
to the legacy e2fsprogs definition.

This remains a review-only userspace/rootfs build. It does not create
approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 57 correction

The workflow:

1. retains every earlier host-tool, PowerTOP, nfnetlink, wireless and
   rootfs-build correction;
2. inventories `blkid.h` and `blkid.h.in` candidates only under the
   pinned util-linux tree;
3. selects the authoritative source template deterministically when it
   exposes the exact const-correct prototype;
4. verifies that the selected public header exposes
   `blkid_dev_set_search` with two `const char *` arguments;
5. requires exactly one legacy e2fsprogs function definition for each
   non-const search argument;
6. changes only those two parameter tokens from `char *` to
   `const char *`;
7. records the candidate inventory, selected header, source revision,
   before/after source, unified patch and machine-readable contract;
8. rejects missing, ambiguous, partial, duplicate, or unexpected
   matches;
9. resumes the native DD-WRT RA72 userspace/rootfs build.

The run stops before the long configure stage if the pinned source no
longer matches this narrow contract.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Preserve all folder paths, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 57: Discover blkid header template and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and run it.

Download this artifact after the run stops:

`ddwrt-ra72-phase57-blkid-header-discovery-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE57.txt`
- `review/phase57-status.txt`
- `review/e2fsprogs-blkid-const-contract.txt`
- `review/e2fsprogs-blkid-const-correctness.patch`
- `review/e2fsprogs-blkid-dev.before.c`
- `review/e2fsprogs-blkid-dev.after.c`
- `review/util-linux-blkid-header-candidates.txt`
- `review/util-linux-blkid-public-header.h`
- `review/host-autoconf-archive-contract.txt`
- `review/powertop-autoconf-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase57-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 57 file.
