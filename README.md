# DD-WRT RA72 Phase 65

Phase 64 successfully resolved the staged `blkid`, `uuid`, and `libudev`
pkg-config contracts. The native DD-WRT configure stage detected both blkid
and libudev, then progressed to a new first fatal blocker in `libmcrypt`:

```text
Invalid configuration `aarch64-linux': machine `aarch64' not recognized
configure: error: /bin/bash ./config.sub aarch64-linux failed
```

Phase 65 replaces only the obsolete Autotools target-recognition helpers
inside DD-WRT's existing `libmcrypt` source tree, verifies the two AArch64
tuples used by this build, and resumes the review-only userspace/rootfs build.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 65 correction

The workflow:

1. pins public DD-WRT source revision `65793` and retains every earlier
   verified correction;
2. locates Ubuntu's maintained `config.guess` and `config.sub`;
3. records the original `libmcrypt` helpers and their pre-correction result;
4. installs byte-identical, executable host copies into
   `src/router/libmcrypt`;
5. verifies both `config.sub aarch64-linux` and
   `config.sub aarch64-uclibc-linux` return successfully;
6. verifies the replacement `config.guess` executes successfully;
7. records hashes, helper output, and a machine-readable contract before the
   long DD-WRT configure/build stage begins;
8. classifies any recurrence as
   `LIBMCRYPT_CONFIG_SUB_AARCH64_UNSUPPORTED`.

This does not replace or upgrade libmcrypt itself. It does not import OpenWrt
code and does not build approved firmware.

## Upload and run

1. Upload the contents of this update over the existing
   `ddwrt-ra72-audit` repository.
2. Preserve every folder path, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 65: Refresh libmcrypt config helpers and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and start the run.

After the run stops, download:

`ddwrt-ra72-phase65-libmcrypt-config-aux-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE65.txt`
- `review/phase65-status.txt`
- `review/libmcrypt-config-aux-contract.txt`
- `review/libmcrypt-config-aux-inventory.txt`
- `review/libmcrypt-config-sub-aarch64.before.txt`
- `review/libmcrypt-config-sub-aarch64.after.txt`
- `review/libmcrypt-config-sub-uclibc.after.txt`
- `review/libmcrypt-config-guess.after.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase65-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file, if any, is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 65 file.
