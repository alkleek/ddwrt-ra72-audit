# Phase 21 — DD-WRT RA72 build-contract reconstruction

Exact device:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018
- board MP03.1
- 128 MiB SPI-NAND

This contract does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

Phase 20 identified `src/router/Makefile.ipq60xx` as the real public DD-WRT
integration point. It contains IPQ5018 rootfs handling and image recipes for
Linksys MR5500 and MX5500.

Phase 21 extracts those source blocks and verifies the common build mechanism
without copying Linksys-specific headers or TRX packaging into the RA72 draft.

The review draft may reference:

- `ipq5018-xiaomi-ra72.dtb`;
- `root.ipq5018`;
- FIT/ITB load and entry address `0x41000000`;
- NAND geometry `-p 128KiB -m 2048`;
- `ubinize-image.sh --kernel ... --rootfs ...`.

The draft must not contain:

- Linksys model headers;
- `trx_n`;
- router-access commands;
- NAND-writing commands;
- boot-environment changes.

No Phase 21 output is firmware or approved for booting or flashing.
