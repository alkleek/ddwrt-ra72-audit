# RA72 Phase 57 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 56 evidence

Phase 56 verified that the pinned legacy e2fsprogs source exists, but
stopped before applying the patch because the hard-coded generated
header path did not yet exist:

```text
public_header_path=src/router/util-linux/libblkid/src/blkid.h
public_header_present=FAIL
```

This is a build-stage path error in our diagnostic script. The
util-linux public header is generated later from a source template;
therefore validation must use the pinned template before configuration.

## Phase 57 contract

Phase 57 searches only under `src/router/util-linux` for the public
`blkid.h` source or template. A file is eligible only if it contains
exactly one const-correct `blkid_dev_set_search` declaration. The
canonical `libblkid/src/blkid.h.in` template has priority; otherwise a
single unambiguous semantic match is required.

After recording every candidate and the selected path, Phase 57 makes
the smallest source-compatible correction in the pinned e2fsprogs
file:

```text
char *search_type   -> const char *search_type
char *search_value  -> const char *search_value
```

Exactly one occurrence of each legacy parameter is required in the
function definition. The run fails closed if header selection is
missing or ambiguous, or if counts or source structure differ. It
stores the candidate inventory, selected header, exact before/after
files, unified diff, source revision and machine-readable contract
before starting the long configure build.

No ABI layout, call site, partition map, kernel, DTB, wireless profile,
boot container or image recipe is changed.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands
are blocked, no router is contacted, and no output is boot-approved.
