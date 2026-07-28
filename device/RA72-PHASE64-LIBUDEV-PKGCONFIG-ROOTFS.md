# RA72 Phase 64 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 63 evidence

The original util-linux `blkid.pc` and `uuid.pc` metadata was rewritten only
for its temporary absolute staging path. Its query and AArch64 uClibc link
test passed, and btrfsprogs configure reported `checking for blkid... yes`.

The next fatal check was `checking for libudev... no` because btrfsprogs uses
pkg-config while DD-WRT's rule supplied only direct include and library search
paths. The same run also showed that generated e2fsprogs MCONFIG intentionally
links against the staged external util-linux blkid/uuid libraries rather than
the older private e2fsprogs library layout.

## Phase 64 contract

Phase 64 generates one isolated `libudev.pc`. Its paths must resolve to:

- the discovered `libudev.h` under DD-WRT's in-tree `src/router/libudev`;
- `src/router/libudev/src/libudev/.libs`;
- the link flag `-ludev`.

The file exists only inside the temporary Phase 64 pkg-config directory. It
does not modify libudev sources or install host-system libudev into the target.

The workflow then requires btrfsprogs configure to report both:

- `checking for blkid... yes`
- `checking for libudev... yes`

The e2fsprogs generated-link diagnostic accepts exactly two known layouts:
the older verified private library layout or the external staged util-linux
layout observed in Phase 63. Unknown assignments still fail closed.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved or flashable.
