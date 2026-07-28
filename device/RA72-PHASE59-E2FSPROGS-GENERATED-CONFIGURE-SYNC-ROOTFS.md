# RA72 Phase 59 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 58 evidence

The Phase 58 artifact pinned DD-WRT revision `65793` and proved:

```text
configure.ac corrected references = 6
configure stale references        = 6
MCONFIG.in matching references    = 0
```

The earlier Phase 58 contract intentionally rejected any pre-existing
corrected reference, so it stopped before modifying the mixed source tree.

## Phase 59 contract

Phase 59 treats `configure.ac` as the semantic source of truth and validates
the exact mixed state above. It then changes only the six private-blkid
basenames in the checked-in generated `configure` script:

```text
$(LIB)/libblkid
```

to:

```text
$(LIB)/libe2fsblkid
```

It does not regenerate `configure`, edit `configure.ac`, edit `MCONFIG.in`, or
create a fallback symlink. Before continuing, hashes prove the two untouched
files did not change and the generated script contains exactly six corrected
references and no stale references.

After the native configure stage, the workflow verifies generated `MCONFIG`,
the built private library and absence of the old e2fsck missing-target error.

No ABI, function signature, partition map, kernel, DTB, wireless profile,
boot container or image recipe is changed by this phase.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved.
