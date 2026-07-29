# DD-WRT RA72 Phase 69

Phase 68 proved that curl now consumes the target OpenSSL3 include and
library paths without leaking the GitHub runner's host OpenSSL `pkg-config`
metadata. The build continued into `libtalloc`, where its Waf configure
selected Python 3.12 from the isolated Meson virtual environment and stopped:

```text
Checking for program 'python3' : .../host-meson-venv/bin/python3
The distutils module is unusable: install "python-devel"?
```

Python 3.12 removed `distutils` from the standard library. Phase 69 keeps every
earlier verified correction and adds a pinned compatibility provider inside
the exact virtual environment selected by `libtalloc`. It does not claim that
the userspace/rootfs build will finish; it continues until the next verified
failure and records that evidence.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Narrow Phase 69 correction

The workflow:

1. pins public DD-WRT source revision `65793`;
2. retains the verified curl target-OpenSSL3 isolation from Phase 68;
3. retains isolated Meson `1.4.2` in its Python virtual environment;
4. installs pinned `setuptools 70.3.0` into that same environment;
5. exports `SETUPTOOLS_USE_DISTUTILS=local`;
6. directly imports `distutils`, `distutils.core`, and
   `distutils.sysconfig` before DD-WRT configure starts;
7. verifies that the provider comes from the virtual environment's
   `setuptools/_distutils` tree;
8. repeats the import check after the cross-toolchain path is active;
9. captures the `libtalloc` rule, Waf config log, complete DD-WRT configure
   log, and exact next-failure classification;
10. fails closed if any compatibility contract is not satisfied.

This is deliberately narrower than changing the GitHub runner's global
Python installation or patching `libtalloc` to skip its own checks.

## Upload and run

1. Extract this update ZIP.
2. Upload its contents over the existing `ddwrt-ra72-audit` repository.
3. Preserve every folder path, including `.github`.
4. Commit the changes.
5. Open **Actions**.
6. Select:

   `Phase 69: Provide libtalloc Python distutils and build rootfs`

7. Press **Run workflow**.
8. Leave all fields unchanged and start the run.

After the run stops, download this complete artifact:

`ddwrt-ra72-phase69-libtalloc-python-distutils-rootfs-build`

Send back the downloaded artifact ZIP without removing any files.

## Most useful review files

- `REPORT-PHASE69.txt`
- `review/phase69-status.txt`
- `review/host-setuptools-distutils-contract.txt`
- `review/host-setuptools-install.log`
- `review/host-setuptools-install-tail.txt`
- `review/libtalloc-distutils-contract.txt`
- `review/libtalloc-rule.mk`
- `review/libtalloc-config.log`
- `review/libtalloc-config-tail.txt`
- `review/curl-target-openssl-pkgconfig-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase69-integration-checks.txt` if produced

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- No approved firmware, UBI image, or Xiaomi installation image is built.
- A generated SquashFS file, if any, remains a review-only component.
- Do not boot, load, install, deploy, or flash any Phase 69 file.
