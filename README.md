# DD-WRT RA72 Phase 32

Phase 31 showed that DD-WRT's complete kernel cannot be built with a
separate `O=` output directory. Its LZMA and MTD Makefiles use relative
include paths and failed to locate `types.h` and `stddef.h`.

Phase 32 repeats the controlled kernel build inside the native DD-WRT source
tree, where those relative paths resolve correctly. It builds the raw ARM64
Linux `Image` together with the exact RA72 DTB and audits the resolved kernel
configuration.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Safety

This phase builds a raw kernel Image and one review DTB only. The Image is
not complete DD-WRT firmware and is not approved for booting. It does not
build a root filesystem, module package, FIT, UBI, BIN, ITB, TRX, or IMG.
It does not contact the router. Do not boot or flash any Phase 32 file.

## Run

In GitHub **Actions**, select:

`Phase 32: Build exact RA72 kernel in native DD-WRT tree`

Press **Run workflow** and leave all three fields unchanged.

The complete kernel export is approximately 1.7 GB, so this workflow may
take longer than the earlier source-only phases. Progress is printed every
30 seconds.

Download:

`ddwrt-ra72-phase32-in-tree-kernel-image-build`

Send back:

- `REPORT-PHASE32.txt`
- `review/phase32-status.txt`
- `review/build-status.txt`
- `review/phase32-integration-checks.txt`
- `review/phase31-root-cause-and-phase32-correction.txt`
- `review/model-identity-resolution.txt`
- `review/native-kernel-kbuild.log`
- `review/native-kernel-image-file.txt`
- `review/native-kernel-image-size.txt`
- `review/ra72-kernel-config-inventory.txt`
- `review/native-dtb-decompile.log`
- `review/warning-summary.txt`
