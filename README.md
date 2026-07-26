# DD-WRT RA72 Phase 44

Phase 44 derives an exact RA72 wireless userspace profile from the
nearest native DD-WRT IPQ6018 configuration, then resumes the native
configure, bootstrap, compile, and rootfs stages.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 43 result

The official AArch64 uClibc-compatible toolchain passed its ARM64
compile test. The public `src/include.v24` tree was exported, five real
`typedefs.h` candidates were found, and the selected header passed
preprocessing. The previous missing-header error was therefore fixed.

The native configure stage then compiled Jansson, wireless-tools, and
most of libutils before stopping at:

`No rule to make target .../register/register_check.o`

The selected base profile enabled legacy `CONFIG_MADWIFI=y`. That
legacy stack requests registration objects not present in the public
source and is not the wireless driver used by RA72.

## Phase 44 corrections

- Preserves every verified Phase 43 source, header, and toolchain fix.
- Starts from the native IPQ6018 configuration and records it unchanged.
- Derives a transparent RA72 profile that enables `CONFIG_ATH11K=y`.
- Explicitly disables MADWIFI, ATH9K, ATH10K, REGISTER,
  SUPERCHANNEL, and the legacy QCA98xx radio selections.
- Records the complete configuration diff and final wireless contract.
- Never fabricates `register_check.o` or substitutes proprietary code.
- Runs native configure, sequential bootstrap, compile, and install.
- Classifies any later configure or build failure separately.
- Searches only verified SquashFS rootfs candidates.
- Keeps every Qualcomm UBI/flash packaging path disabled.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 44: Apply RA72 wireless profile and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase44-ra72-wireless-profile-rootfs-build`

Send back the complete downloaded artifact ZIP. The most useful files
inside it are:

- `REPORT-PHASE44.txt`
- `review/phase44-status.txt`
- `review/base-ipq60xx.config`
- `review/selected-ipq60xx.config`
- `review/ra72-wireless-profile.patch`
- `review/ra72-wireless-profile-contract.txt`
- `review/ra72-wireless-profile-changes.txt`
- `review/register-source-inventory.txt`
- `review/ddwrt-header-tree-contract.txt`
- `review/typedefs-header-candidates.txt`
- `review/typedefs-preprocess.log`
- `review/header-include-contract.txt`
- `review/source-layout-contract.txt`
- `review/configure-stage-status.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/bootstrap-stage-status.txt`
- `review/ddwrt-bootstrap-build-tail.txt`
- `review/jansson-rule.mk`
- `review/jansson-before-configure.txt`
- `review/jansson-after-configure.txt`
- `review/userspace-build-status.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase44-integration-checks.txt` if present

## Safety

This workflow never contacts the router. It does not produce an
approved firmware image. Any rootfs is a review-only component and must
not be booted or flashed.
