# DD-WRT RA72 Phase 56

Phase 55 passed its intended PowerTOP Autoconf Archive repair and
advanced the pinned DD-WRT configure build to `e2fsprogs/lib/blkid`.
The first current hard failure is an exact C prototype mismatch:

```text
dev.c:130:12: error: conflicting types for 'blkid_dev_set_search'
have 'int(struct blkid_struct_dev_iterate *, char *, char *)'
previous declaration ... has type
'int(struct blkid_struct_dev_iterate *, const char *, const char *)'
```

The legacy e2fsprogs copy declares and defines the two search arguments
as writable strings, while the newer public util-linux `blkid.h` used
by the DD-WRT build declares both arguments `const`.

Phase 56 applies one source-scoped const-correctness patch to the pinned
e2fsprogs `dev.c`, records exact before/after evidence, verifies the
public-header contract, and resumes the same native rootfs build.

This remains a review-only userspace/rootfs build. It does not create
approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 56 correction

The workflow:

1. retains every Phase 55 host-tool, PowerTOP, nfnetlink, wireless and
   rootfs-build correction;
2. verifies that the pinned util-linux public header exposes
   `blkid_dev_set_search` with two `const char *` arguments;
3. requires exactly one legacy e2fsprogs function definition for each
   non-const search argument;
4. changes only those two parameter tokens from `char *` to
   `const char *`;
5. records the source revision, public header, before/after source,
   unified patch and machine-readable contract;
6. rejects a partial, duplicate, or unexpected patch;
7. classifies recurrence of the original compiler error explicitly;
8. resumes the native DD-WRT RA72 userspace/rootfs build.

The run stops before the long configure stage if the pinned source no
longer matches this narrow contract.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Preserve all folder paths, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 56: Correct e2fsprogs blkid const types and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and run it.

Download this artifact after the run stops:

`ddwrt-ra72-phase56-e2fsprogs-blkid-const-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE56.txt`
- `review/phase56-status.txt`
- `review/e2fsprogs-blkid-const-contract.txt`
- `review/e2fsprogs-blkid-const-correctness.patch`
- `review/e2fsprogs-blkid-dev.before.c`
- `review/e2fsprogs-blkid-dev.after.c`
- `review/util-linux-blkid-public-header.h`
- `review/host-autoconf-archive-contract.txt`
- `review/powertop-autoconf-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase56-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 56 file.
