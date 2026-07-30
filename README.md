# DD-WRT RA72 Phase 75

Phase 74 proved that disabling the optional `libubox` examples was correct:
the native DD-WRT configure, build, and install steps succeeded and staged
the AArch64 `libubox` core library. The remaining failure is now narrower:
`json-c` was not present in `src/router/_staging`, so libubox CMake reported
`json-NOTFOUND` and could not build `libblobmsg_json.so`.

Phase 75 stages the native DD-WRT `json-c` dependency first, verifies its
target ABI and pkg-config metadata, and only then rebuilds `libubox` with the
already validated examples-off option. It requires libubox CMake to resolve
the staged json-c library and requires both `libubox.so` and
`libblobmsg_json.so` before continuing to `ubus` and the review-only rootfs
build.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 75 contract

The workflow:

1. pins public DD-WRT source revision `65793`;
2. preserves every validated correction through Phase 74;
3. verifies the native `rules/json-c.mk`, source tree, and exact `json-c`
   build target before running it;
4. runs the native json-c configure target when the rule provides one;
5. requires staged json-c headers, an AArch64 shared library, `json-c.pc`,
   and a successful isolated pkg-config query;
6. preserves the minimal `-DBUILD_EXAMPLES=OFF` libubox correction and
   `-DBUILD_LUA=off`;
7. requires libubox CMake to report examples disabled and staged json-c
   resolved;
8. requires the Phase 73 `json_script-example` NOTFOUND failure to remain
   absent;
9. builds and stages `libubox.so`, `libblobmsg_json.so`, and headers;
10. requires both staged libubox libraries to be AArch64;
11. continues native `ubus` configuration and the review-only rootfs build;
12. records the first later blocker and fails closed if any contract fails.

This phase does not claim rootfs or firmware completion. A later dependency
failure is expected evidence for the next phase.

## Upload and run

1. Extract this update ZIP.
2. Upload all its contents over the existing `ddwrt-ra72-audit` repository.
3. Preserve every folder path, including `.github`.
4. Commit the changes.
5. Open **Actions**.
6. Select **Phase 75: Stage json-c before libubox and build rootfs**.
7. Press **Run workflow**.
8. Leave all fields unchanged and start the run.

After the run stops, download this complete artifact:

`ddwrt-ra72-phase75-json-c-staging-rootfs-build`

Send back the downloaded artifact ZIP without removing any files.

## Most useful review files

- `REPORT-PHASE75.txt`
- `review/phase75-status.txt`
- `review/json-c-rule.mk`
- `review/json-c-rule-inventory.txt`
- `review/json-c-staging-contract.txt`
- `review/json-c-staging-preflight.log`
- `review/json-c-staged-files.txt`
- `review/json-c-pkgconfig-query.txt`
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
- `review/phase75-integration-checks.txt` if produced

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- No approved firmware, UBI image, or Xiaomi installation image is built.
- A generated SquashFS file, if any, remains a review-only component.
- Do not boot, load, install, deploy, or flash any Phase 75 file.
