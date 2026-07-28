# RA72 Phase 58 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 57 evidence

Phase 57 passed its complete const-correctness contract. Its configure
log then proved both sides of a private e2fsprogs library-name mismatch:

```text
created: ../libe2fsblkid.so
requested: ../lib/libblkid.so
```

The private blkid library compiled and linked successfully. The
`e2fsck` target stopped only because its configured dependency used the
public-library basename rather than the private-library basename.

## Phase 58 contract

Phase 58 searches only the authoritative, top-level e2fsprogs
configuration sources for the exact expression:

```text
$(LIB)/libblkid
```

It records all matches, requires a bounded and exact source contract,
then changes only the basename:

```text
$(LIB)/libe2fsblkid
```

The correction is applied before the native DD-WRT configure stage.
After configure, the workflow records generated `MCONFIG`, verifies its
effective `LIBBLKID` path, inventories the built private libraries and
checks that the Phase 57 missing-target error is gone.

No compatibility symlink is synthesized. No ABI, function signature,
partition map, kernel, DTB, wireless profile, boot container or image
recipe is changed by this phase.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands
are blocked, no router is contacted, and no output is boot-approved.
