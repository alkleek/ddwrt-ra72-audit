# RA72 Phase 72 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 71 evidence

The paired socket/netlink UAPI contract passed and FRR configuration reached
its protobuf checks. Target `libprotobuf-c` was available, but the host code
generator was not:

```text
checking for protoc-c... no
configure: error: protobuf requested but protoc-c not found. Install protobuf-c
```

This is a host-build dependency, not a target RA72 library or device-tree
failure.

## Phase 72 contract

The phase requires:

- Ubuntu's `protobuf-c-compiler` package to own an executable `protoc-c`;
- package and tool versions to be recorded;
- an isolated Proto input to generate non-empty `.pb-c.c` and `.pb-c.h`
  outputs;
- the native DD-WRT FRR configure segment to be captured;
- FRR's `checking for protoc-c...` result to be successful;
- the exact Phase 71 missing-tool failure to be absent;
- all earlier RA72 source, toolchain and userspace contracts to remain valid.

If configuration or building stops later, Phase 72 records the first new
blocker instead of claiming rootfs completion.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging remains blocked,
no router is contacted, and no output is boot-approved or flashable.
