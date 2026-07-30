# RA72 Phase 73 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 72 evidence

The host `protoc-c` compiler was installed and passed the isolated generation
preflight. FRR detected it and the Phase 71 missing-tool failure disappeared.
The build then reached native `ubus` configuration and stopped because its
three libubox inputs were unresolved:

```text
blob_library ... NOTFOUND
ubox_include_dir ... NOTFOUND
ubox_library ... NOTFOUND
ubox_include_dir-NOTFOUND
make: *** [rules/ubus.mk:15: ubus-configure] Error 1
```

This is a target staging and dependency-order problem. It is not a DTB,
kernel, RA72 hardware, or host-`protoc-c` failure.

## Phase 73 contract

The phase requires:

- native DD-WRT `libubox-configure` and `libubox` make targets to exist;
- both targets to complete successfully;
- installation into `src/router/_staging/usr`;
- staged `libubox/blob.h`, `libubox/blobmsg.h`, `libubox.so` and
  `libblobmsg_json.so`;
- both staged shared libraries to be identified as AArch64 target files;
- the native `ubus` CMake cache to resolve `ubox_include_dir`,
  `ubox_library` and `blob_library`;
- no resolved value to contain `NOTFOUND`;
- the exact Phase 72 failure to be absent;
- all earlier RA72 source, toolchain, kernel, DTB and userspace contracts to
  remain valid.

If configuration or building stops later, Phase 73 records the first new
blocker rather than claiming rootfs completion.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging remains blocked,
no router is contacted, and no output is boot-approved or flashable.
