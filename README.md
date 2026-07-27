# DD-WRT RA72 Phase 51

Phase 51 installs and verifies the host `gtkdocize` tool, then
preconfigures `util-linux` through DD-WRT's native target before the
full configure, bootstrap, userspace, and rootfs build. It preserves all
verified toolchain, PCRE, libsodium, libltdl, and ncurses contracts.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Verified Phase 46 result

All four generated `revision.h` files matched the pinned public DD-WRT
SVN revision `65774`. The missing-revision-header error disappeared.

PCRE 8.41 then successfully built these production libraries:

- `libpcre`
- `libpcreposix`
- `libpcrecpp`

Phase 46 built all three PCRE production libraries and excluded only
the three cross-compiled unit tests. Its complete machine-readable
contract passed. Configuration then advanced to libsodium and stopped
because its `autogen.sh` replacement `build-aux/config.sub` could not
be executed.

## Verified Phase 48 result

The complete 4,217,788,956-byte official DD-WRT toolchain archive
downloaded successfully on the first resumable attempt. Source export,
toolchain selection, PCRE production libraries, and every libsodium
configuration-helper check passed.

Configuration then advanced into `dnscrypt`. Its nested `autoreconf`
stopped because:

```text
libtoolize: error: '/usr/share/aclocal/ltdl.m4' does not exist.
```

## Verified Phase 49 result

Ubuntu's `libltdl-dev` package supplied the missing macro and its
machine-readable host contract passed. DD-WRT configuration advanced
past `dnscrypt` and later stopped at:

```text
make -C ncurses
make[1]: *** No targets specified and no makefile found. Stop.
make: *** [rules/ncurses.mk:29: ncurses] Error 2
```

The failure means the native build requested `ncurses` before
`src/router/ncurses/Makefile` had been generated.

## Verified Phase 50 result

The native `ncurses-configure` target existed, completed successfully,
and generated a verified `src/router/ncurses/Makefile`. DD-WRT built
ncurses and advanced to `util-linux`, where `autoreconf` stopped at:

```text
Can't exec "gtkdocize": No such file or directory
autoreconf: error: gtkdocize failed with exit status: 2
make: *** [rules/util-linux.mk:8: util-linux-configure] Error 2
```

## Phase 51 correction

- Preserves the pinned source revision, official DD-WRT toolchain,
  exact RA72 ATH11K profile, native header tree, and revision metadata.
- Preserves and revalidates the successful Phase 50 ncurses contract.
- Installs Ubuntu's `gtk-doc-tools` package explicitly.
- Verifies `/usr/bin/gtkdocize` before downloading the large toolchain.
- Records the tool's package provider, version, SHA-256 hash, and
  executable status.
- Saves the exact native `src/router/rules/util-linux.mk`.
- Requires and runs DD-WRT's native `util-linux-configure` target before
  the full configure stage.
- Requires a generated `src/router/util-linux/Makefile` before
  continuing.
- Saves focused preconfigure/config logs, final 500 lines, before/after
  inventory, generated Makefile hash, and a machine-readable contract.
- Classifies recurrence of the Phase 50 gtkdocize failure explicitly.
- Keeps Qualcomm UBI and every flash/deployment path disabled.

This is a narrow build correction. It does not claim that DD-WRT is
ready to boot on RA72.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 51: Add gtkdocize and preconfigure util-linux`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase51-gtkdocize-util-linux-rootfs-build`

Send back the complete downloaded artifact ZIP. The most useful files
inside it are:

- `REPORT-PHASE51.txt`
- `review/phase51-status.txt`
- `review/host-libltdl-contract.txt`
- `review/ncurses-rule.mk`
- `review/ncurses-before-preconfigure.txt`
- `review/ncurses-after-preconfigure.txt`
- `review/ncurses-preconfigure-contract.txt`
- `review/ncurses-preconfigure-tail.txt`
- `review/ncurses-preconfigure.log`
- `review/host-gtkdocize-contract.txt`
- `review/util-linux-rule.mk`
- `review/util-linux-before-preconfigure.txt`
- `review/util-linux-after-preconfigure.txt`
- `review/util-linux-preconfigure-contract.txt`
- `review/util-linux-preconfigure-tail.txt`
- `review/util-linux-preconfigure.log`
- `review/util-linux-config.log` if present
- `review/toolchain-download-contract.txt`
- `review/toolchain-download-attempts.txt`
- `review/toolchain-download-tail.txt`
- `review/pcre-production-targets.txt`
- `review/pcre-library-only.patch`
- `review/pcre-built-libraries.txt`
- `review/pcre-library-contract.txt`
- `review/sodium-config-aux.patch`
- `review/sodium-config-aux-patch-contract.txt`
- `review/system-config-aux-sources.txt`
- `review/libsodium-config-aux-contract.txt`
- `review/libsodium-config-guess-output.txt`
- `review/libsodium-config-sub-output.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/bootstrap-stage-status.txt`
- `review/ddwrt-bootstrap-build-tail.txt`
- `review/userspace-build-status.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase51-integration-checks.txt` if present

## Safety

This workflow never contacts the router. It does not produce approved
firmware. Any SquashFS rootfs is a review-only component and must not
be booted or flashed.
