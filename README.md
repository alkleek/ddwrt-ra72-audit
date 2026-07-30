# DD-WRT RA72 Phase 74

Phase 73 reached the native DD-WRT `libubox-configure` target. Its CMake
generation failed because the upstream examples were enabled automatically
and `json_script-example` tried to link a missing library named `json`.
This happened before the required `libubox` libraries could be built and
staged for `ubus`.

Phase 74 applies one narrow source-rule correction:

`UBOX_CMAKE_OPTIONS=-DBUILD_LUA=off -DBUILD_EXAMPLES=OFF`

It verifies that the original option occurs exactly once, preserves
`BUILD_LUA=off`, adds `BUILD_EXAMPLES=OFF` exactly once, confirms from
`CMakeCache.txt` that examples are disabled, and then continues the native
`libubox`, `ubus`, and review-only rootfs build.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 74 contract

The workflow:

1. pins public DD-WRT source revision `65793`;
2. preserves every validated correction through Phase 73;
3. verifies the unmodified native `rules/libubox.mk` option line exactly;
4. adds only `-DBUILD_EXAMPLES=OFF` while preserving `-DBUILD_LUA=off`;
5. records the before/after rule and exact unified diff;
6. runs the native `libubox-configure` target;
7. requires `libubox/CMakeCache.txt` to contain
   `BUILD_EXAMPLES:BOOL=OFF`;
8. requires the Phase 73 `json_script-example` NOTFOUND failure to be absent;
9. builds and stages target `libubox.so`, `libblobmsg_json.so`, and headers;
10. requires the staged libraries to be AArch64;
11. continues the native `ubus` configuration and review-only rootfs build;
12. records the first later blocker and fails closed if any contract fails.

This phase does not claim rootfs or firmware completion. A later dependency
failure is expected evidence for the next phase.

## Upload and run

1. Extract this update ZIP.
2. Upload all its contents over the existing `ddwrt-ra72-audit` repository.
3. Preserve every folder path, including `.github`.
4. Commit the changes.
5. Open **Actions**.
6. Select **Phase 74: Disable libubox examples and build rootfs**.
7. Press **Run workflow**.
8. Leave all fields unchanged and start the run.

After the run stops, download this complete artifact:

`ddwrt-ra72-phase74-libubox-examples-off-rootfs-build`

Send back the downloaded artifact ZIP without removing any files.

## Most useful review files

- `REPORT-PHASE74.txt`
- `review/phase74-status.txt`
- `review/libubox-rule.mk.before`
- `review/libubox-rule.mk.after`
- `review/libubox-disable-examples.patch`
- `review/libubox-examples-off-contract.txt`
- `review/libubox-CMakeCache.txt`
- `review/libubox-staging-contract.txt`
- `review/libubox-staging-preflight.log`
- `review/libubox-staged-files.txt`
- `review/ubus-cmake-cache.txt`
- `review/ubus-libubox-configure-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase74-integration-checks.txt` if produced

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- No approved firmware, UBI image, or Xiaomi installation image is built.
- A generated SquashFS file, if any, remains a review-only component.
- Do not boot, load, install, deploy, or flash any Phase 74 file.
