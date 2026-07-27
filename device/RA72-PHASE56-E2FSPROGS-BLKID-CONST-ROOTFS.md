# RA72 Phase 56 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 55 evidence

The intended Phase 55 correction passed:

- Ubuntu `autoconf-archive` and all four required PowerTOP macros were
  present;
- the pinned PowerTOP `configure.ac` referenced those macros;
- the focused `libtoolize`, `aclocal`, and `autoconf` preflight passed;
- generated `aclocal.m4` contained `AX_PTHREAD`;
- the former misleading undefined `AC_MSG_ERROR` failure was absent.

The build then reached `e2fsprogs/lib/blkid/dev.c`. That legacy source
declares and defines `blkid_dev_set_search` with writable
`char *search_type` and `char *search_value` parameters. Its active
public declaration comes from the newer util-linux `blkid.h`, where
both parameters are `const char *`. GCC correctly rejects these as
conflicting function types.

## Phase 56 contract

Phase 56 verifies the public util-linux prototype first, then makes the
smallest source-compatible correction in the pinned e2fsprogs file:

```text
char *search_type   -> const char *search_type
char *search_value  -> const char *search_value
```

Exactly one occurrence of each legacy parameter is required in the
function definition. The run fails closed if counts or source structure
differ. It stores the exact before/after files, unified diff, source
revision and machine-readable contract before starting the long
configure build.

No ABI layout, call site, partition map, kernel, DTB, wireless profile,
boot container or image recipe is changed.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands
are blocked, no router is contacted, and no output is boot-approved.
