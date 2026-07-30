# RA72 Phase 74 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 73 evidence

The native DD-WRT `libubox-configure` target was selected correctly, but its
CMake generation stopped in the optional examples subtree:

`json` was NOTFOUND and was linked by `json_script-example`.

The native rule used only `-DBUILD_LUA=off`. Upstream `libubox` exposes
`BUILD_EXAMPLES`, so this is an optional-example dependency problem rather
than an RA72 hardware, kernel, DTB, or core-libubox problem.

## Phase 74 contract

The phase requires:

- the original `UBOX_CMAKE_OPTIONS=-DBUILD_LUA=off` line exactly once;
- a minimal one-line edit adding `-DBUILD_EXAMPLES=OFF`;
- `BUILD_LUA=off` to remain present;
- `libubox/CMakeCache.txt` to report `BUILD_EXAMPLES:BOOL=OFF`;
- the Phase 73 `json_script-example` NOTFOUND failure to be absent;
- native DD-WRT `libubox-configure` and `libubox` targets to succeed;
- target headers and shared libraries to be staged under
  `src/router/_staging/usr`;
- staged `libubox.so` and `libblobmsg_json.so` to be AArch64;
- native `ubus` CMake to resolve the staged libubox inputs;
- all earlier RA72 contracts to remain valid.

Before/after rule copies, the unified diff, CMake cache, build log, staging
inventory, and fail-closed contracts are retained in the artifact.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging remains blocked,
no router is contacted, and no output is boot-approved or flashable.
