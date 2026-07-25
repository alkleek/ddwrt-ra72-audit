# Phase 32 in-tree DD-WRT kernel-build contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

This is not the Xiaomi Mi Router AX6000 (IPQ8072A), Redmi AX6000, or any
device whose label does not state RA72.

## Phase 31 finding

The out-of-tree kernel build reached the native DD-WRT driver and library
sources, then failed at:

- `lib/lzma/LzFind.c`: forced include `types.h` was not found;
- `include/linux/lzma/Types.h`: `stddef.h` was not found.

The DD-WRT Makefiles add relative include paths such as `-Iinclude/linux`
and `-Ilib/lzma`. With `O=<separate-output-directory>`, those paths were
resolved relative to the output tree rather than the source tree.

This is a build-layout incompatibility, not an RA72 Device Tree failure.

## Phase 32 correction

Phase 32:

- removes the out-of-tree `O=...` build argument;
- places the resolved `.config_ipq6018` at the native kernel root;
- builds `Image` and `qcom/ipq5018-xiaomi-ra72.dtb` in the DD-WRT source
  tree, matching the relative paths expected by its Makefiles;
- records the Phase 31 root cause and confirms that the source headers
  exist before compiling;
- captures a specific blocked status on build failure.

No source workaround is applied to LZMA headers, and no compiler error is
suppressed.

## Safety boundary

The raw kernel Image is a **review artifact**, not complete DD-WRT firmware.
No root filesystem, modules package, FIT image, UBI, BIN, ITB, TRX, or IMG
is produced. No router, SSH session, UART, NAND partition, or boot variable
is accessed. Nothing from this phase is approved for booting or flashing.
