# DD-WRT RA72 Phase 36

This is the corrected accelerated userspace/rootfs build following the
Phase 35 script-control failure.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## What changed

- The failed diagnostic dry run can no longer stop the workflow.
- The actual native DD-WRT build now starts even when dry-run expansion
  returns a non-zero diagnostic code.
- Build failures are captured and classified instead of being converted
  into `BLOCKED_UNEXPECTED_ERROR`.
- The separate kernel source export is skipped to preserve runner space;
  the verified kernel work remains covered by Phases 30–34.

## Upload and run

1. Upload this update over the existing GitHub repository.
2. Keep `.github` and all folder paths.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 36: Build corrected DD-WRT RA72 userspace rootfs`

6. Press **Run workflow** and leave both fields unchanged.

The actual build can take one to several hours. A red result still uploads
the diagnostic artifact.

Download:

`ddwrt-ra72-phase36-corrected-userspace-rootfs-build`

Send back:

- `REPORT-PHASE36.txt`
- `review/phase36-status.txt`
- `review/userspace-build-status.txt`
- `review/build-failure-classification.txt`
- `review/userspace-build-tail.txt`
- `review/userspace-toolchain-contract.txt`
- `review/source-summary.txt`
- `review/phase36-integration-checks.txt` if present
- `review/rootfs-superblock.txt` if present
- `review/rootfs-busybox-type.txt` if present

Do not boot or flash any Phase 36 output.
