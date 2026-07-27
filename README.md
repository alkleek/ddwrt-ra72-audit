# DD-WRT RA72 Phase 54

Phase 54 corrects the exact failure found by Phase 53:

```text
../include/linux/netfilter/nfnetlink.h:4:10: fatal error:
linux/netfilter/nfnetlink_compat.h: No such file or directory
make: *** [rules/nftables.mk:19: libnftnl] Error 2
```

Phase 53 itself passed its intended Meson correction. The isolated
Meson `1.4.2` was active and satisfied GLib's minimum `1.4.0`.

This remains a review-only userspace/rootfs build. It does not create
approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 54 correction

The workflow:

1. exports the DD-WRT router and Linux 6.12 NSS trees from the same
   pinned public SVN revision;
2. requires the canonical UAPI source header:
   `src/linux/universal/linux-6.12-nss/include/uapi/linux/netfilter/nfnetlink_compat.h`;
3. materializes that header at the location used by DD-WRT userspace:
   `src/router/kernel_headers/include/linux/netfilter/nfnetlink_compat.h`;
4. verifies source and destination paths, revision, SHA-256 hashes,
   byte identity, and include guard;
5. records the complete result in
   `review/nfnetlink-compat-header-contract.txt`;
6. retains the Meson and all earlier corrections;
7. continues the native DD-WRT RA72 userspace/rootfs build.

The header is not downloaded from an unrelated project or kernel. It is
copied from the Linux source exported at the exact DD-WRT revision used
by the same run.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Preserve all folder paths, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 54: Restore nfnetlink compat header and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and run it.

Download this artifact after the run stops:

`ddwrt-ra72-phase54-nfnetlink-compat-header-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE54.txt`
- `review/phase54-status.txt`
- `review/nfnetlink-compat-header-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase54-integration-checks.txt` if produced

The Phase 53 Meson contract and all earlier focused evidence remain
included in the artifact.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 54 file.
