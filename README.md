# DD-WRT RA72 Phase 60

Phase 59 completed its intended generated-`configure` synchronization and
proved that the private `libe2fsblkid.so` is built. The build then exposed a
new, exact linker defect in the generated e2fsprogs `MCONFIG`:

```text
LIBBLKID = $(LIB)/libe2fsblkid.so # $(LIBUUID)
```

The comment marker prevents `-luuid` from reaching the blkid link command.
The resulting failure reports `libuuid.so.0` as missing and leaves
`uuid_unparse` and `uuid_is_null` undefined.

Phase 60 activates that one verified UUID dependency in the source template,
proves the generated link order, and resumes the review-only userspace/rootfs
build.

This phase does not produce approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 60 correction

The workflow:

1. pins the public DD-WRT source at revision `65793` and retains all earlier
   verified corrections;
2. re-verifies the exact Phase 58/59 generated-`configure` synchronization;
3. requires exactly one commented UUID dependency and no active equivalent
   in `src/router/e2fsprogs/MCONFIG.in`;
4. changes only:

   ```text
   LIBBLKID = @LIBBLKID@ # $(LIBUUID)
   ```

   to:

   ```text
   LIBBLKID = @LIBBLKID@ $(LIBUUID)
   ```

5. records before/after copies, SHA-256 values, a unified patch and a
   machine-readable contract;
6. proves that `configure` and `configure.ac` were not changed by this new
   correction;
7. verifies that util-linux produced `libuuid.so`;
8. verifies that generated `MCONFIG` requests private `libe2fsblkid` followed
   by `$(LIBUUID)`, where `LIBUUID = -luuid`;
9. verifies the actual blkid link command orders `libe2fsblkid.so` before
   `-luuid`;
10. proves that the Phase 59 missing-library warning and UUID undefined
    references are absent before accepting later build results.

No Autoconf regeneration and no fallback symlink are used. Any source layout
other than the exact verified Phase 59 state stops safely.

## Upload and run

1. Upload the contents of this update over the existing
   `ddwrt-ra72-audit` repository.
2. Preserve every folder path, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 60: Repair e2fsprogs private blkid UUID link and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and start the run.

After the run stops, download:

`ddwrt-ra72-phase60-e2fsprogs-private-blkid-uuid-link-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE60.txt`
- `review/phase60-status.txt`
- `review/e2fsprogs-private-blkid-uuid-template-contract.txt`
- `review/e2fsprogs-private-blkid-uuid-template.patch`
- `review/e2fsprogs-MCONFIG.in.before`
- `review/e2fsprogs-MCONFIG.in.after`
- `review/e2fsprogs-private-blkid-generated-contract.txt`
- `review/e2fsprogs-private-blkid-built-files.txt`
- `review/e2fsprogs-private-blkid-uuid-built-files.txt`
- `review/e2fsprogs-generated-MCONFIG.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase60-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file, if any, is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 60 file.
