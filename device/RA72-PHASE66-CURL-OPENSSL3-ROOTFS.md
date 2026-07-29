# RA72 Phase 66 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 65 evidence

The Phase 65 contracts confirmed that the maintained `config.guess` and
`config.sub` copies were installed into `src/router/libmcrypt`, were
executable, matched the verified host copies, and accepted both
`aarch64-linux` and `aarch64-uclibc-linux`. The old AArch64 recognition
failure was absent.

The native configure stage then successfully generated the OpenSSL3
Makefile. The next fatal command came from `rules/curl.mk`, which still ran
`make -C openssl`. DD-WRT revision 65793 uses `src/router/openssl3`, so the
legacy directory had no Makefile and curl configure stopped.

## Phase 66 contract

Phase 66 verifies the exact curl rule shape before editing it and requires:

- `src/router/rules/curl.mk` and `src/router/openssl3` to be present;
- exactly one active recipe reference to `-C openssl`;
- exactly one recipe line to change;
- no active `-C openssl` recipe reference after the correction;
- at least one active `-C openssl3` recipe reference after the correction;
- the rule diff and before/after hashes to be recorded;
- the Phase 65 missing legacy OpenSSL Makefile failure to be absent after the
  next configure attempt.

The correction is deliberately limited to the curl build dependency. No
OpenSSL or curl implementation, ABI, configuration option, or RA72 hardware
definition is changed.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved or flashable.
