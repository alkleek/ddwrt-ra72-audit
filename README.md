# DD-WRT RA72 Phase 55

Phase 55 corrects the exact failure found after Phase 54 passed its
intended `nfnetlink_compat.h` repair:

```text
cd powertop && aclocal
cd powertop && autoconf
configure.ac:52: error: possibly undefined macro: AC_MSG_ERROR
```

The apparent `AC_MSG_ERROR` failure is nested inside PowerTOP's
`AX_PTHREAD` call. The current PowerTOP `configure.ac` also requires
`AX_REQUIRE_DEFINED`, `AX_ADD_FORTIFY_SOURCE`, and
`AX_CXX_COMPILE_STDCXX`. Those `AX_*` macros are supplied by the
distribution's `autoconf-archive` package.

This remains a review-only userspace/rootfs build. It does not create
approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 55 correction

The workflow:

1. installs Ubuntu's `autoconf-archive` package on the temporary GitHub
   runner;
2. verifies the package version and locates the provider file for every
   required PowerTOP `AX_*` macro under `/usr/share/aclocal`;
3. records paths and SHA-256 hashes in
   `review/host-autoconf-archive-contract.txt`;
4. exports `ACLOCAL_PATH=/usr/share/aclocal` for the complete DD-WRT
   build;
5. checks the exact macro references in the pinned PowerTOP
   `configure.ac`;
6. performs a focused `libtoolize`, `aclocal`, and `autoconf` preflight;
7. requires the generated `aclocal.m4` to contain the `AX_PTHREAD`
   definition and rejects the Phase 54 undefined-macro failure;
8. records this in `review/powertop-autoconf-contract.txt`;
9. retains the Phase 54 nfnetlink contract and all earlier corrections;
10. continues the native DD-WRT RA72 userspace/rootfs build.

If the package, any required macro, or the focused preflight is missing,
the run stops before the long full configure stage.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Preserve all folder paths, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 55: Provide PowerTOP Autoconf Archive macros and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and run it.

Download this artifact after the run stops:

`ddwrt-ra72-phase55-powertop-autoconf-archive-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE55.txt`
- `review/phase55-status.txt`
- `review/host-autoconf-archive-contract.txt`
- `review/powertop-autoconf-contract.txt`
- `review/powertop-autoconf-preflight.log`
- `review/powertop-configure.ac`
- `review/powertop-aclocal.m4`
- `review/nfnetlink-compat-header-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase55-integration-checks.txt` if produced

The Phase 54 nfnetlink contract and all earlier focused evidence remain
included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 55 file.
