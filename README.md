# DD-WRT RA72 Phase 68

Phase 67 proved that the narrow OpenSSL3 recursive-make correction works.
The build entered curl's configure stage, but host `pkg-config` metadata then
overrode the target flags:

```text
configure: pkg-config: SSL_LDFLAGS: "-L/usr/lib/x86_64-linux-gnu "
configure: pkg-config: SSL_CPPFLAGS: "-I/usr/include "
checking for openssl/x509.h... no
configure: error: OpenSSL libs and/or directories were not found where specified!
```

Phase 68 keeps every earlier verified correction and isolates only curl's
main target configure block from host OpenSSL metadata. It does not claim that
the userspace/rootfs build will finish; it continues until the next verified
failure and records that evidence.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Narrow Phase 68 correction

The workflow:

1. pins public DD-WRT source revision `65793`;
2. retains the verified `openssl3` dependency and `MAKE=make` correction;
3. finds exactly one main `curl/build` configure block and one separate
   `curl/build_static` block;
4. adds `PKG_CONFIG="/tmp"` only to the main target configure invocation;
5. preserves curl's explicit `-I$(SSLPATH)/include`,
   `-L$(SSLPATH)`, and `--with-openssl` flags;
6. verifies that the static configure block is unchanged;
7. fails closed if the expected source shape is absent or ambiguous;
8. checks that host `/usr/include` and `/usr/lib/x86_64-linux-gnu` OpenSSL
   metadata no longer enters curl's configure result;
9. records the exact diff, contracts, logs, and next failure classification.

This is deliberately smaller than disabling `pkg-config` globally. Other
DD-WRT packages keep their existing configuration behavior.

## Upload and run

1. Extract this update ZIP.
2. Upload its contents over the existing `ddwrt-ra72-audit` repository.
3. Preserve every folder path, including `.github`.
4. Commit the changes.
5. Open **Actions**.
6. Select:

   `Phase 68: Isolate curl target OpenSSL and build rootfs`

7. Press **Run workflow**.
8. Leave all fields unchanged and start the run.

After the run stops, download this complete artifact:

`ddwrt-ra72-phase68-curl-target-openssl-pkgconfig-rootfs-build`

Send back the downloaded artifact ZIP without removing any files.

## Most useful review files

- `REPORT-PHASE68.txt`
- `review/phase68-status.txt`
- `review/curl-target-openssl-pkgconfig-contract.txt`
- `review/curl-target-openssl-pkgconfig.patch`
- `review/curl-rule.mk.phase67`
- `review/curl-rule.mk.after`
- `review/curl-openssl3-rule-contract.txt`
- `review/openssl3-recursive-make-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase68-integration-checks.txt` if produced

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- No approved firmware, UBI image, or Xiaomi installation image is built.
- A generated SquashFS file, if any, remains a review-only component.
- Do not boot, load, install, deploy, or flash any Phase 68 file.
