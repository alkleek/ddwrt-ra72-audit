# RA72 Phase 55 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 54 evidence

The intended nfnetlink compatibility-header repair passed:

- the source existed in the pinned DD-WRT Linux 6.12 NSS UAPI tree;
- the header was materialized into the userspace kernel-headers tree;
- source and destination were byte-identical;
- the include guard and provenance contract passed.

The full configure advanced into PowerTOP. Its local `aclocal` and
`autoconf` sequence then stopped because `AX_PTHREAD` was not defined.
The nested argument to that macro caused Autoconf to report the
misleading visible token `AC_MSG_ERROR`.

## Phase 55 contract

Phase 55 installs and verifies Ubuntu's `autoconf-archive` package,
which supplies the exact PowerTOP macros:

- `AX_REQUIRE_DEFINED`
- `AX_ADD_FORTIFY_SOURCE`
- `AX_CXX_COMPILE_STDCXX`
- `AX_PTHREAD`

The run records the package version, provider paths, and hashes; exports
the host aclocal search path; verifies the references in the pinned
PowerTOP source; and completes a focused Autoconf preflight before the
long DD-WRT configure stage. The Phase 54 header repair remains active
and its contract is retained.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands
are blocked, no router is contacted, and no output is boot-approved.
