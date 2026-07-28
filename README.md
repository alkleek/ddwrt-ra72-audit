# DD-WRT RA72 Phase 59

Phase 58 stopped safely before changing the source because the pinned
e2fsprogs tree contains a mixed but deterministic state:

```text
configure.ac: 6 corrected $(LIB)/libe2fsblkid references
configure:    6 stale     $(LIB)/libblkid references
MCONFIG.in:   0 matching references
```

The authoritative Autoconf input is already correct, while its checked-in
generated `configure` script is stale. Phase 59 synchronizes only those six
generated references with `configure.ac`, verifies the result and resumes the
review-only userspace/rootfs build.

This phase does not produce approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 59 correction

The workflow:

1. pins the public DD-WRT source at the Phase 58 revision `65793` and
   retains every earlier verified correction;
2. checks that `configure.ac` contains exactly six corrected
   `$(LIB)/libe2fsblkid` references and no stale references;
3. checks that generated `configure` contains exactly six stale
   `$(LIB)/libblkid` references and no corrected references;
4. requires `MCONFIG.in` to contain neither form;
5. changes only those six stale basenames inside generated `configure`;
6. proves that `configure` and `configure.ac` then contain the same six
   corrected references and zero stale references;
7. records the complete inventory, before/after generated script, unified
   patch, hashes and machine-readable contract;
8. verifies after configuration that generated `MCONFIG` requests
   `libe2fsblkid`, the private shared library was built and the Phase 57
   missing-target error is absent;
9. resumes the native DD-WRT RA72 userspace/rootfs build.

No Autoconf regeneration and no compatibility symlink are used. Any source
layout other than the exact verified Phase 58 layout stops safely.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Preserve all folder paths, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 59: Synchronize e2fsprogs generated configure and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and run it.

Download this artifact after the run stops:

`ddwrt-ra72-phase59-e2fsprogs-generated-configure-sync-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE59.txt`
- `review/phase59-status.txt`
- `review/e2fsprogs-generated-configure-sync-contract.txt`
- `review/e2fsprogs-generated-configure-sync.patch`
- `review/e2fsprogs-generated-configure-sync-candidates.txt`
- `review/e2fsprogs-generated-configure.before`
- `review/e2fsprogs-generated-configure.after`
- `review/e2fsprogs-private-blkid-generated-contract.txt`
- `review/e2fsprogs-private-blkid-built-files.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase59-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 59 file.
