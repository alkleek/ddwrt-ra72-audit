# RA72 Phase 63 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 62 evidence

Phase 62 proved that the focused util-linux staged install contains:

- target blkid and UUID headers;
- `libblkid.a` and `libuuid.a`;
- generated `blkid.pc` and `uuid.pc`.

It also proved that the isolated pkg-config query succeeds and that a real
AArch64 uClibc program using blkid links successfully. Phase 62 stopped only
because its diagnostic expected `-luuid`, although the generated `blkid.pc`
does not declare UUID as a private dependency and the successful link does not
need it.

## Phase 63 contract

Phase 63 copies the two generated target `.pc` files to an isolated temporary
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
- `pkg-config --static --libs blkid` includes `-lblkid`;
- the result points to the staged target library directory;
- `-luuid` is present if and only if the generated `blkid.pc` declares the
  UUID dependency;
- an AArch64 uClibc test program using the blkid API links successfully.

After configuration, it requires btrfsprogs to detect blkid and proves the
earlier static-description error is absent. A later unrelated failure is
reported separately with the full log and exact classification.

No DD-WRT source ABI, partition map, kernel, DTB, wireless profile, boot
container, or image recipe is changed by this phase.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved or flashable.
