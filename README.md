# DD-WRT RA72 Phase 72

Phase 71 successfully repaired and verified the paired Linux socket/netlink
UAPI contract. DD-WRT configuration then reached FRR and stopped because the
GitHub runner did not provide the host `protoc-c` executable:

```text
checking for protoc-c... no
configure: error: protobuf requested but protoc-c not found. Install protobuf-c
```

The target `libprotobuf-c` dependency was already detected. Phase 72 therefore
adds the official Ubuntu `protobuf-c-compiler` host package, tests `protoc-c`
with a small isolated Proto-to-C generation, verifies that FRR detects it, and
then continues the same review-only rootfs build to expose the next result.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 72 contract

The workflow:

1. pins public DD-WRT source revision `65793`;
2. installs Ubuntu's official `protobuf-c-compiler` host package;
3. records the executable path, package provider and versions;
4. requires `protoc-c` to generate non-empty C and H files from a small
   isolated Proto definition before the expensive source build begins;
5. preserves all corrections and checks verified through Phase 71;
6. captures the focused FRR configure segment;
7. requires FRR to detect `protoc-c`;
8. requires the exact Phase 71 missing-`protoc-c` failure to be absent;
9. continues configuration/rootfs work and classifies the first later blocker;
10. fails closed if either the host preflight or FRR contract fails.

This phase does not claim that the rootfs build will finish. A later
dependency failure is expected evidence for the next phase.

## Upload and run

1. Extract this update ZIP.
2. Upload its contents over the existing `ddwrt-ra72-audit` repository.
3. Preserve every folder path, including `.github`.
4. Commit the changes.
5. Open **Actions**.
6. Select:

   `Phase 72: Provide host protoc-c and build rootfs`

7. Press **Run workflow**.
8. Leave all fields unchanged and start the run.

After the run stops, download this complete artifact:

`ddwrt-ra72-phase72-host-protoc-c-rootfs-build`

Send back the downloaded artifact ZIP without removing any files.

## Most useful review files

- `REPORT-PHASE72.txt`
- `review/phase72-status.txt`
- `review/host-protoc-c-contract.txt`
- `review/host-protoc-c-preflight.log`
- `review/frr-protoc-c-configure-segment.txt`
- `review/frr-protoc-c-configure-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase72-integration-checks.txt` if produced

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- No approved firmware, UBI image, or Xiaomi installation image is built.
- A generated SquashFS file, if any, remains a review-only component.
- Do not boot, load, install, deploy, or flash any Phase 72 file.
