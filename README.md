# DD-WRT RA72 Phase 66

Phase 65 successfully refreshed the obsolete `libmcrypt` Autotools helpers.
Both AArch64 target tuples passed, `libmcrypt` configured, and the build moved
to the next exact blocker. DD-WRT configured `openssl3` successfully, but the
active curl rule later invoked the obsolete directory:

```text
make -j 8 -C openssl
make[1]: *** No targets specified and no makefile found. Stop.
make: *** [rules/curl.mk:30: curl-configure] Error 2
```

Phase 66 changes only that verified curl dependency from `openssl` to
`openssl3`, records the one-line diff and rule contract, then resumes the
review-only userspace/rootfs build.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 66 correction

The workflow:

1. pins public DD-WRT source revision `65793` and retains every earlier
   verified correction;
2. retains and verifies the Phase 65 `libmcrypt` correction;
3. requires the native `src/router/openssl3` source and `rules/curl.mk`;
4. records the original curl rule and its SHA-256 hash;
5. replaces exactly one recipe dependency from `-C openssl` to
   `-C openssl3`;
6. fails closed if the verified one-line shape is absent or ambiguous;
7. records the patched rule, unified diff, hashes, reference counts, and a
   machine-readable contract;
8. classifies any recurrence as
   `CURL_LEGACY_OPENSSL_MAKEFILE_MISSING`.

This does not replace or upgrade OpenSSL or curl. It does not import OpenWrt
code and does not build approved firmware.

## Upload and run

1. Upload the contents of this update over the existing
   `ddwrt-ra72-audit` repository.
2. Preserve every folder path, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 66: Repair curl OpenSSL3 dependency and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and start the run.

After the run stops, download:

`ddwrt-ra72-phase66-curl-openssl3-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE66.txt`
- `review/phase66-status.txt`
- `review/curl-openssl3-rule-contract.txt`
- `review/curl-rule.mk.before`
- `review/curl-rule.mk.after`
- `review/curl-openssl3-rule.patch`
- `review/curl-openssl-references.before.txt`
- `review/curl-openssl-references.after.txt`
- `review/libmcrypt-config-aux-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase66-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file, if any, is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 66 file.
