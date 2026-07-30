# DD-WRT RA72 Phase 73

Phase 72 successfully supplied and verified the host `protoc-c` compiler.
The isolated Proto-to-C test passed, FRR detected the tool, and the earlier
missing-`protoc-c` failure disappeared.

The build then reached `ubus` and exposed the next blocker:

```text
blob_library ... NOTFOUND
ubox_include_dir ... NOTFOUND
ubox_library ... NOTFOUND
ubox_include_dir-NOTFOUND
make: *** [rules/ubus.mk:15: ubus-configure] Error 1
```

Phase 73 addresses only this newly verified dependency-order problem. It uses
the native DD-WRT `libubox-configure` and `libubox` targets, stages their target
headers and shared libraries under `src/router/_staging`, verifies that the
libraries are AArch64, and then requires the native `ubus` CMake cache to
resolve all three libubox inputs without `NOTFOUND`.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 73 contract

The workflow:

1. pins public DD-WRT source revision `65793`;
2. preserves every validated correction through Phase 72;
3. verifies the native `rules/libubox.mk` and `rules/ubus.mk` contracts;
4. runs the native `libubox-configure` and `libubox` make targets;
5. installs the result into the target staging root at
   `src/router/_staging/usr`;
6. requires staged `libubox` headers, `libubox.so` and
   `libblobmsg_json.so`;
7. requires the staged shared libraries to be AArch64 target files;
8. runs the native DD-WRT configure stage;
9. requires `ubus/CMakeCache.txt` to resolve `ubox_include_dir`,
   `ubox_library` and `blob_library`;
10. requires the exact Phase 72 libubox-`NOTFOUND` failure to be absent;
11. continues the review-only rootfs build and records the first later
    blocker;
12. fails closed if any Phase 73 contract is not satisfied.

This phase does not claim that the rootfs build will finish. A later
dependency failure is useful evidence for the next phase.

## Upload and run

1. Extract this update ZIP.
2. Upload all its contents over the existing `ddwrt-ra72-audit` repository.
3. Preserve every folder path, including `.github`.
4. Commit the changes.
5. Open **Actions**.
6. Select:

   `Phase 73: Stage libubox before ubus and build rootfs`

7. Press **Run workflow**.
8. Leave all fields unchanged and start the run.

After the run stops, download this complete artifact:

`ddwrt-ra72-phase73-libubox-staging-rootfs-build`

Send back the downloaded artifact ZIP without removing any files.

## Most useful review files

- `REPORT-PHASE73.txt`
- `review/phase73-status.txt`
- `review/libubox-staging-contract.txt`
- `review/libubox-staging-preflight.log`
- `review/libubox-ubus-rule-inventory.txt`
- `review/libubox-rule.mk`
- `review/ubus-rule.mk`
- `review/libubox-staged-files.txt`
- `review/ubus-cmake-cache.txt`
- `review/ubus-libubox-configure-contract.txt`
- `review/ubus-libubox-configure-segment.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase73-integration-checks.txt` if produced

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- No approved firmware, UBI image, or Xiaomi installation image is built.
- A generated SquashFS file, if any, remains a review-only component.
- Do not boot, load, install, deploy, or flash any Phase 73 file.
