# DD-WRT RA72 Phase 71

Phase 70 successfully copied the exact pinned Linux 6.12 NSS
`include/uapi/linux/netlink.h` into DD-WRT's restricted userspace header
tree. Source and destination hashes matched, but the focused AArch64 uClibc
preflight exposed the next transitive dependency:

```text
error: unknown type name '__kernel_sa_family_t'
```

Phase 71 keeps every earlier verified correction and materializes the exact
`include/uapi/linux/socket.h` dependency from the same pinned Linux source
tree. That header defines `__kernel_sa_family_t`, which `linux/netlink.h`
uses for `struct sockaddr_nl`. The workflow then reruns the focused cross
compile and continues the rootfs build only if the paired socket/netlink
header contract passes. It does not claim that the userspace/rootfs build
will finish; it records the next verified result.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Narrow Phase 71 correction

The workflow:

1. pins public DD-WRT source revision `65793`;
2. retains the verified Phase 69 Python/distutils compatibility contract;
3. takes `include/uapi/linux/socket.h` only from the pinned DD-WRT Linux
   `linux-6.12-nss` tree;
4. stages it at `src/router/kernel_headers/include/linux/socket.h`, the
   exact userspace include tree passed to bundled `libusb`;
5. verifies source and destination hashes and byte-for-byte identity;
6. verifies the socket UAPI include guard and the
   `__kernel_sa_family_t` typedef;
7. compiles a focused paired socket/netlink preflight with DD-WRT's official
   AArch64 uClibc compiler and the same include path;
8. verifies that the `usb_modeswitch/libusb` configure segment detects
   `linux/netlink.h` and that the Phase 69 missing-header failure is absent;
9. captures the complete DD-WRT configure/build logs and classifies the
   first next failure;
10. fails closed if either UAPI header contract is not satisfied.

This is deliberately narrower than using the GitHub runner's host headers,
inventing a local typedef, or patching bundled `libusb` to skip its netlink
check.

## Upload and run

1. Extract this update ZIP.
2. Upload its contents over the existing `ddwrt-ra72-audit` repository.
3. Preserve every folder path, including `.github`.
4. Commit the changes.
5. Open **Actions**.
6. Select:

   `Phase 71: Stage Linux socket UAPI and build rootfs`

7. Press **Run workflow**.
8. Leave all fields unchanged and start the run.

After the run stops, download this complete artifact:

`ddwrt-ra72-phase71-linux-socket-uapi-rootfs-build`

Send back the downloaded artifact ZIP without removing any files.

## Most useful review files

- `REPORT-PHASE71.txt`
- `review/phase71-status.txt`
- `review/linux-socket-uapi-header-contract.txt`
- `review/linux-netlink-uapi-header-contract.txt`
- `review/linux-socket-netlink-uapi-preflight.log`
- `review/linux-socket-netlink-uapi-preflight-tail.txt`
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
- `review/phase71-integration-checks.txt` if produced

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- No approved firmware, UBI image, or Xiaomi installation image is built.
- A generated SquashFS file, if any, remains a review-only component.
- Do not boot, load, install, deploy, or flash any Phase 71 file.
