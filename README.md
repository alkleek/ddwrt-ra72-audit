# DD-WRT RA72 Phase 41

Phase 41 resolves the first two real source-layout blockers found after
Phase 40 successfully downloaded, extracted, tested, and used the
official DD-WRT AArch64 toolchain.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 40 result

The official toolchain passed its ARM64 compile test and the native
DD-WRT build started. It stopped at the first preparation rule because:

- the repository-level `opt` tree had not been exported, so
  `src/router/opt/etc/config/*.webconfig` was unavailable;
- `linux-6.12-nss/.config` was read before the later kernel rule copied
  `.config_ipq6018` into place.

## Phase 41 corrections

- Exports `opt` and `tools` from the same pinned DD-WRT SVN revision.
- Resolves and records the `src/router/opt` topology.
- Requires real DD-WRT `*.webconfig` files; it creates no placeholders.
- Copies the native `.config_ipq6018` before any userspace rule reads it.
- Runs the native compile stage and then the native install/rootfs stage.
- Searches verified SquashFS candidates named `root.ipq5018`,
  `root.ipq60xx`, or `root.fs`.
- Keeps every Qualcomm UBI/flash packaging path disabled.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 41: Resolve source opt and build DD-WRT RA72 rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase41-source-opt-kernel-config-rootfs-build`

Send back the complete downloaded artifact ZIP. The most useful files
inside it are:

- `REPORT-PHASE41.txt`
- `review/phase41-status.txt`
- `review/source-layout-contract.txt`
- `review/opt-resolution.txt`
- `review/webconfig-contract.txt`
- `review/userspace-build-status.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase41-integration-checks.txt` if present

## Safety

This workflow never contacts the router. It does not produce an
approved firmware image. Any rootfs is a review-only component and must
not be booted or flashed.
