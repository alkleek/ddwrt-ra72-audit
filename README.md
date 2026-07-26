# DD-WRT RA72 Phase 46

Phase 46 fixes the first blocker found in Phase 45, then continues the
native DD-WRT configure, bootstrap, userspace, and rootfs build.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Verified Phase 45 result

All four generated `revision.h` files matched the pinned public DD-WRT
SVN revision `65774`. The missing-revision-header error disappeared.

PCRE 8.41 then successfully built these production libraries:

- `libpcre`
- `libpcreposix`
- `libpcrecpp`

The configure stage stopped only while linking three cross-compiled
PCRE unit-test executables. Their linker could not resolve the indirect
`libpcre.so.1` dependency of `libpcrecpp.so`. These test executables are
not runtime components of the RA72 rootfs.

## Phase 46 correction

- Preserves the pinned source revision, official DD-WRT toolchain,
  exact RA72 ATH11K profile, native header tree, and revision metadata.
- Patches only the `pcre` recipe in `src/router/rules/pcre.mk`.
- Requests exactly the three production library targets:
  `libpcre.la`, `libpcreposix.la`, and `libpcrecpp.la`.
- Does not request nonlibrary PCRE programs during this configure
  prerequisite; in particular, it excludes the three failing
  `pcrecpp_unittest`, `pcre_scanner_unittest`, and
  `pcre_stringpiece_unittest` targets.
- Saves the original and patched rule, a unified diff, the selected
  targets, resulting libraries, and a machine-readable contract.
- Stops immediately if the expected PCRE recipe is not found exactly
  once or if any required production library is missing.
- Keeps Qualcomm UBI and every flash/deployment path disabled.

This is a narrow build correction. It does not claim that DD-WRT is
ready to boot on RA72.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 46: Build PCRE libraries only and continue rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase46-pcre-library-only-rootfs-build`

Send back the complete downloaded artifact ZIP. The most useful files
inside it are:

- `REPORT-PHASE46.txt`
- `review/phase46-status.txt`
- `review/pcre-production-targets.txt`
- `review/pcre-library-only.patch`
- `review/pcre-built-libraries.txt`
- `review/pcre-library-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/bootstrap-stage-status.txt`
- `review/ddwrt-bootstrap-build-tail.txt`
- `review/userspace-build-status.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase46-integration-checks.txt` if present

## Safety

This workflow never contacts the router. It does not produce approved
firmware. Any SquashFS rootfs is a review-only component and must not
be booted or flashed.
