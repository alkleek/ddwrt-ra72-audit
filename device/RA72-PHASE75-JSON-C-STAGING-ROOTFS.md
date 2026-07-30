# RA72 Phase 75 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 74 evidence

The Phase 74 examples-off correction worked. Native DD-WRT configured, built,
and installed the core `libubox` library as AArch64, and the former
`json_script-example` failure did not recur.

The focused CMake cache instead reported `json-NOTFOUND`. The staged tree
contained `libubox.so` and headers but no `libblobmsg_json.so`, because the
native json-c dependency had not yet been built and staged. This is a
dependency-order problem, not an RA72 hardware, kernel, DTB, or core-libubox
failure.

## Phase 75 contract

The phase requires:

- the native DD-WRT json-c rule, source tree, and exact build target;
- the native json-c configure step when its rule exposes one;
- json-c headers, shared library, and pkg-config metadata in
  `src/router/_staging/usr`;
- the staged json-c shared library to be AArch64;
- an isolated staged-tree `pkg-config --cflags --libs json-c` query;
- the validated `-DBUILD_EXAMPLES=OFF` correction to remain applied;
- `BUILD_LUA=off` to remain present;
- `libubox/CMakeCache.txt` to report `BUILD_EXAMPLES:BOOL=OFF`;
- libubox CMake to report JSONC found and its `json` library resolved;
- the Phase 73 `json_script-example` NOTFOUND failure to be absent;
- native DD-WRT `libubox-configure` and `libubox` targets to succeed;
- target headers and shared libraries to be staged under
  `src/router/_staging/usr`;
- staged `libubox.so` and `libblobmsg_json.so` to be AArch64;
- native `ubus` CMake to resolve the staged libubox inputs;
- all earlier RA72 contracts to remain valid.

The json-c rule inventory, configure/build log, staging inventory,
pkg-config query, libubox before/after rule copies, unified diff, CMake cache,
and fail-closed contracts are retained in the artifact.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging remains blocked,
no router is contacted, and no output is boot-approved or flashable.
