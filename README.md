# DD-WRT RA72 Phase 70

Phase 69 proved that the pinned `setuptools` compatibility provider works
inside the exact Python 3.12 virtual environment selected by `libtalloc`.
All direct `distutils` checks passed and the Phase 68 `libtalloc` failure
disappeared. The build then continued to the bundled `libusb` configure used
by `usb_modeswitch`, where it stopped because its restricted DD-WRT header
path did not contain the Linux netlink UAPI header:

```text
checking for linux/netlink.h... no
configure: error: Linux netlink header not found
```

Phase 70 keeps every earlier verified correction and materializes the exact
`linux/netlink.h` file from DD-WRT's pinned Linux 6.12 NSS source tree into
the userspace kernel-header tree consumed by that configure step. It validates
the copied header with the AArch64 uClibc cross compiler before continuing.
It does not claim that the userspace/rootfs build will finish; it records the
next verified result.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Narrow Phase 70 correction

The workflow:

1. pins public DD-WRT source revision `65793`;
2. retains the verified Phase 69 Python/distutils compatibility contract;
3. takes `include/uapi/linux/netlink.h` only from the pinned DD-WRT Linux
   `linux-6.12-nss` tree;
4. stages it at `src/router/kernel_headers/include/linux/netlink.h`, the
   exact userspace include tree passed to bundled `libusb`;
5. verifies source and destination hashes and byte-for-byte identity;
6. compiles a focused `linux/netlink.h` preflight with DD-WRT's official
   AArch64 uClibc compiler and the same include path;
7. verifies that the `usb_modeswitch/libusb` configure segment detects the
   header and that the Phase 69 missing-header failure is absent;
8. captures the complete DD-WRT configure/build logs and classifies the
   first next failure;
9. fails closed if the new header contract is not satisfied.

This is deliberately narrower than using the GitHub runner's host kernel
headers or patching bundled `libusb` to skip its netlink check.

## Upload and run

1. Extract this update ZIP.
2. Upload its contents over the existing `ddwrt-ra72-audit` repository.
3. Preserve every folder path, including `.github`.
4. Commit the changes.
5. Open **Actions**.
6. Select:

   `Phase 70: Stage Linux netlink UAPI and build rootfs`

7. Press **Run workflow**.
8. Leave all fields unchanged and start the run.

After the run stops, download this complete artifact:

`ddwrt-ra72-phase70-linux-netlink-uapi-rootfs-build`

Send back the downloaded artifact ZIP without removing any files.

## Most useful review files

- `REPORT-PHASE70.txt`
- `review/phase70-status.txt`
- `review/linux-netlink-uapi-header-contract.txt`
- `review/linux-netlink-uapi-preflight.log`
- `review/linux-netlink-uapi-preflight-tail.txt`
- `review/usb-modeswitch-libusb-configure-segment.txt`
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
- `review/phase70-integration-checks.txt` if produced

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- No approved firmware, UBI image, or Xiaomi installation image is built.
- A generated SquashFS file, if any, remains a review-only component.
- Do not boot, load, install, deploy, or flash any Phase 70 file.
