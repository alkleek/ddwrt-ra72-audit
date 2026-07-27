# RA72 Phase 52 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 51 evidence

The host gtk-doc tool, ncurses preconfiguration, and util-linux
preconfiguration all passed. The generated util-linux Makefile then ran
ownership-changing install hooks in the unprivileged GitHub runner:

```text
chgrp tty .../usr/bin/wall
chown root:root .../bin/mount
```

Both failed with `Operation not permitted`.

## Phase 52 contract

The DD-WRT util-linux configure recipe is changed exactly once to include:

```text
--disable-makeinstall-chown
--disable-use-tty-group
```

Phase 52 stops unless all of these are true:

- the patch changed exactly one recipe;
- each new option appears exactly once;
- native `util-linux-configure` succeeds;
- the generated Makefile has no active ownership-changing recipes;
- a direct staged `make install` succeeds without `sudo`;
- no `chown`/`chgrp` permission failure appears;
- the focused installation produced files.

After those checks, the normal DD-WRT configure and review-only rootfs
build continue. Any later failure is preserved with full logs and a
narrow failure classification.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved.
