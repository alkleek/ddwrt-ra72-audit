# RA72 Phase 15 kernel-baseline contract

This phase is limited to the **Xiaomi Mi AIoT AX6000**, model **RA72**:

- Qualcomm IPQ5018
- board configuration MP03.1
- ARM64

It is not for the Xiaomi Mi Router AX6000 (IPQ8072A), Redmi AX6000, or any
device whose label does not state RA72.

Phase 15 performs a read-only source audit. It compares the verified OpenWrt
reference with the public DD-WRT source inventory to identify:

1. the closest DD-WRT kernel tree suitable for an ARM64 Qualcomm baseline;
2. the available Qualcomm ARM64 Device Tree roots;
3. any explicit IPQ5018 or IPQ50xx platform signals;
4. the remaining platform work required before a build prototype is possible.

The result is evidence, not firmware. This phase must not:

- build a boot image;
- generate a flashable file;
- access or modify a router;
- claim DD-WRT compatibility;
- reuse an image intended for another AX6000 product.

Any later prototype must remain boot-only and separately reviewed before it is
allowed near the RA72 hardware.
