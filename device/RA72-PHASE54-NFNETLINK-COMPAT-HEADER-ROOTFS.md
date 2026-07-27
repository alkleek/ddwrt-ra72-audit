# RA72 Phase 54 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 53 evidence

The isolated Meson correction passed:

- virtual environment creation passed;
- Meson `1.4.2` was installed and selected;
- it met GLib's declared minimum `1.4.0`;
- the isolated executable remained active after adding the cross
  toolchain to `PATH`.

The full configure advanced into `libnftnl`, where multiple translation
units failed because DD-WRT's userspace `kernel_headers` tree lacked
`linux/netfilter/nfnetlink_compat.h`.

## Phase 54 contract

Phase 54 restores only that missing header from:

`src/linux/universal/linux-6.12-nss/include/uapi/linux/netfilter/nfnetlink_compat.h`

to:

`src/router/kernel_headers/include/linux/netfilter/nfnetlink_compat.h`

Both trees are exported from the exact same pinned DD-WRT SVN revision.
The run stops before configuration if the source is absent, the copy is
empty, the files differ, or the expected include guard is missing.
Paths, revision, hashes, and byte identity are recorded for review.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved.
