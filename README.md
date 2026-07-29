# DD-WRT RA72 Phase 67

Phase 66 successfully redirected the stale curl dependency from `openssl` to
the native `openssl3` tree. The build then entered `openssl3`, but its
generated Makefile quoted the inherited parallel make command as one program
name:

```text
make -j 8 -C openssl3
"make -j 8" depend && "make -j 8" _build_sw
/bin/sh: 1: make -j 8: not found
make: *** [rules/curl.mk:30: curl-configure] Error 2
```

Phase 67 retains the verified OpenSSL3 dependency and adds `MAKE=make` only to
that one submake. The outer DD-WRT build remains parallel, while the quoted
recursive command inside OpenSSL3 resolves to the real `make` executable.
The workflow records the exact one-line diff and resumes the review-only
userspace/rootfs build.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 67 correction

The workflow:

1. pins public DD-WRT source revision `65793` and retains every earlier
   verified correction;
2. retains and verifies the Phase 66 redirect to `src/router/openssl3`;
3. requires exactly one active recipe shaped as
   `$(MAKE) -C openssl3`;
4. changes that recipe to `$(MAKE) -C openssl3 MAKE=make`;
5. fails closed if the verified one-line shape is absent or ambiguous;
6. records the patched rule, unified diff, hashes, reference counts, and a
   machine-readable recursive-make contract;
7. requires the configure log to show the new override invocation;
8. requires the Phase 66 `"make -j N": not found` failure to be absent;
9. classifies any recurrence as
   `OPENSSL3_QUOTED_RECURSIVE_MAKE_NOT_FOUND`.

This does not replace or upgrade OpenSSL or curl and does not disable
parallelism for the outer DD-WRT build. It does not import OpenWrt code and
does not build approved firmware.

## Upload and run

1. Upload the contents of this update over the existing
   `ddwrt-ra72-audit` repository.
2. Preserve every folder path, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 67: Repair OpenSSL3 recursive make and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and start the run.

After the run stops, download:

`ddwrt-ra72-phase67-openssl3-recursive-make-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE67.txt`
- `review/phase67-status.txt`
- `review/curl-openssl3-rule-contract.txt`
- `review/openssl3-recursive-make-contract.txt`
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
- `review/phase67-integration-checks.txt` if produced

All earlier focused evidence remains included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file, if any, is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 67 file.
