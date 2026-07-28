# DD-WRT RA72 Phase 58

Phase 57 successfully discovered the authoritative util-linux blkid
template and applied the verified const-correctness patch. The build
then reached e2fsprogs and exposed a separate deterministic mismatch:

```text
No rule to make target '../lib/libblkid.so', needed by 'e2fsck'.
```

The same log proves that the pinned private e2fsprogs build creates
`libe2fsblkid.so`, not `libblkid.so`. Phase 58 therefore corrects the
authoritative e2fsprogs configuration source so consumers request the
private library name that the build actually produces.

This remains a review-only userspace/rootfs build. It does not create
approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 58 correction

The workflow:

1. retains every earlier verified correction, including the Phase 57
   const-correct blkid function patch;
2. scans only the top-level pinned e2fsprogs configuration sources
   `configure`, `configure.ac` and `MCONFIG.in`;
3. inventories exact private-library references before changing them;
4. replaces only the `$(LIB)/libblkid` basename with
   `$(LIB)/libe2fsblkid`, preserving the source's extension syntax;
5. requires one or more exact references and rejects unrelated or
   ambiguous source layouts;
6. records the complete inventory, before/after files, unified patch,
   hashes and a machine-readable contract;
7. verifies after configuration that generated `MCONFIG` points to
   `libe2fsblkid`, that the produced library exists, and that the
   Phase 57 missing-target error is absent;
8. resumes the native DD-WRT RA72 userspace/rootfs build.

No fallback symlink is created. If the pinned DD-WRT source changes,
the workflow stops safely with review evidence.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Preserve all folder paths, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 58: Repair e2fsprogs private blkid link and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and run it.

Download this artifact after the run stops:

`ddwrt-ra72-phase58-e2fsprogs-private-blkid-link-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE58.txt`
- `review/phase58-status.txt`
- `review/e2fsprogs-private-blkid-link-contract.txt`
- `review/e2fsprogs-private-blkid-link.patch`
- `review/e2fsprogs-private-blkid-link-candidates.txt`
- `review/e2fsprogs-private-blkid-generated-contract.txt`
- `review/e2fsprogs-private-blkid-built-files.txt`
- `review/e2fsprogs-blkid-const-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase58-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 58 file.
