# RA72 Phase 62 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 61 evidence

Phase 61 verified that the pinned e2fsprogs template correction is exact,
generated `MCONFIG` contains the required UUID dependency, both target
libraries are produced, and the real link command is ordered correctly.

The first later fatal error is from btrfsprogs:

```text
configure: error: pkg-config description of blkid, needed for static build, is not available
```

The same run proves the focused util-linux staged install contains:

- target blkid and UUID headers;
- `libblkid.a` and `libuuid.a`;
- generated `blkid.pc` and `uuid.pc`.

The dependency exists, but the native btrfsprogs configure process cannot
discover its static pkg-config description.

## Phase 62 contract

Phase 62 copies the two generated target `.pc` files to an isolated temporary
directory and changes only these four location assignments:

- `prefix`
- `exec_prefix`
- `libdir`
- `includedir`

The paths point to the focused util-linux staging tree. Package names,
versions, compile flags, link flags, and private dependency declarations are
preserved.

Before the long DD-WRT configure stage, the workflow requires:

- both `.pc` sources and both static archives are present;
- `pkg-config --exists blkid uuid` succeeds;
- `pkg-config --static --libs blkid` includes `-lblkid` and `-luuid`;
- the result points to the staged target library directory;
- an AArch64 uClibc test program using the blkid API links successfully.

After configuration, it requires btrfsprogs to detect blkid and proves the
Phase 61 static-description error is absent. A later unrelated failure is
reported separately with the full log and exact classification.

No DD-WRT source ABI, partition map, kernel, DTB, wireless profile, boot
container, or image recipe is changed by this phase.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved or flashable.
