# RA72 Phase 67 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 66 evidence

The Phase 66 contract confirmed that exactly one active curl recipe was
changed from `-C openssl` to `-C openssl3`. The legacy directory failure was
absent and the build reached the native OpenSSL3 Makefile.

The next fatal command was:

```text
make -j 8 -C openssl3
"make -j 8" depend && "make -j 8" _build_sw
/bin/sh: 1: make -j 8: not found
```

The OpenSSL3 Makefile quotes its recursive `$(MAKE)`. With DD-WRT's inherited
parallel value, the shell treats `make -j 8` as a single executable name.

## Phase 67 contract

Phase 67 verifies the exact curl rule shape before editing it and requires:

- `src/router/rules/curl.mk` and `src/router/openssl3` to be present;
- the retained Phase 66 redirect to `-C openssl3`;
- exactly one active plain `$(MAKE) -C openssl3` recipe;
- no pre-existing `MAKE=make` override;
- exactly one recipe line to change;
- exactly one `$(MAKE) -C openssl3 MAKE=make` recipe afterward;
- the rule diff and before/after hashes to be recorded;
- the configure log to show the override invocation;
- the Phase 66 quoted recursive-make failure to be absent after the next
  configure attempt.

The correction is deliberately limited to the OpenSSL3 dependency submake
inside the curl rule. The outer DD-WRT make retains its parallel jobs. No
OpenSSL or curl implementation, ABI, configuration option, or RA72 hardware
definition is changed.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved or flashable.
