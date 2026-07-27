# RA72 Phase 53 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 52 evidence

The util-linux correction passed its complete contract:

- both ownership-changing configure options were applied exactly once;
- focused preconfiguration and staged installation returned status zero;
- the generated Makefile had no active `chown root:root` or `chgrp tty`;
- 349 files totaling 10,991,967 bytes were staged.

The full DD-WRT configure then stopped in GLib because Ubuntu's Meson
`1.3.2` did not meet GLib's declared minimum `1.4.0`.

## Phase 53 contract

Before downloading the large source and toolchain archives, Phase 53:

- creates an isolated Python virtual environment;
- installs exactly Meson `1.4.2`;
- verifies that the active `meson` command resolves to that environment;
- requires the actual and pinned versions to be identical;
- records the original system Meson version, executable path, SHA-256,
  and pip version;
- stops immediately with a narrow status if any contract fails.

The isolated Meson path remains active after the DD-WRT cross-toolchain
is added. The configure and build classifiers explicitly recognize the
old-Meson error.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved.
