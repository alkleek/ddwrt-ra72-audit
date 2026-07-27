# DD-WRT RA72 Phase 49

Phase 49 adds the host `libltdl` development macro required by
`dnscrypt` and continues the native DD-WRT configure, bootstrap,
userspace, and rootfs build. It preserves the successful resumable
toolchain download and libsodium correction from Phase 48.

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

## Phase 49 correction

- Preserves the pinned source revision, official DD-WRT toolchain,
  exact RA72 ATH11K profile, native header tree, and revision metadata.
- Preserves the Phase 48 resumable download strategy and all verified
  PCRE/libsodium corrections.
- Installs Ubuntu's `libltdl-dev` package explicitly.
- Verifies `/usr/share/aclocal/ltdl.m4` before downloading the large
  toolchain or exporting the DD-WRT source.
- Records the macro provider and SHA-256 hash in a machine-readable
  contract.
- Stops immediately with a specific status if the macro is unavailable.
- Preserves and revalidates the narrow Phase 46 PCRE library-only patch.
- Installs Ubuntu's `autotools-dev` package in the GitHub runner.
- Patches only the libsodium configure chain in
  `src/router/rules/sodium.mk`.
- Runs libsodium's native `autogen.sh`, then replaces the downloaded
  `config.guess` and `config.sub` with executable copies supplied by
  Ubuntu before running `./configure`.
- Verifies both helpers are executable, runs `config.guess`, and tests
  `config.sub aarch64-linux-uclibc`.
- Saves the original and patched sodium rule, a unified diff, helper
  hashes and outputs, and a machine-readable contract.
- Stops if the expected sodium chain is not found exactly once or any
  helper check fails.
- Keeps Qualcomm UBI and every flash/deployment path disabled.

This is a narrow build correction. It does not claim that DD-WRT is
ready to boot on RA72.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 49: Add libltdl support and continue dnscrypt/rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase49-libltdl-dnscrypt-rootfs-build`

Send back the complete downloaded artifact ZIP. The most useful files
inside it are:

- `REPORT-PHASE49.txt`
- `review/phase49-status.txt`
- `review/host-libltdl-contract.txt`
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
- `review/phase49-integration-checks.txt` if present

## Safety

This workflow never contacts the router. It does not produce approved
firmware. Any SquashFS rootfs is a review-only component and must not
be booted or flashed.
