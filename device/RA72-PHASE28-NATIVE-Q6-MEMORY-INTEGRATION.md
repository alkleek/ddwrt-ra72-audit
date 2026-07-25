# Phase 28 native Q6-memory integration contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

## Phase 27 finding

The native internal GE PHY was identified uniquely and corrected to
`ge_phy: ethernet-phy@7`. DTC then reached the native WCSS remoteproc node
and reported two missing labels:

- `q6_region`
- `q6_etr_region`

These references come from the active native DD-WRT `ipq5018.dtsi`, not from
the imported RA72 board source.

## Phase 28 correction

Resolve label references across the actual RA72 source-include closure.
For each referenced but undefined Q6 label, extract its complete balanced node
from DD-WRT's direct IPQ5018 image-template boards:

- `ipq5018-mr5500.dts`
- `ipq5018-mx5500.dts`

Both templates must agree after whitespace normalization. MX2000 is excluded
because it is not a direct Phase 21 image template and uses a different ETR
memory address.

Expected native ranges:

- `q6_region`: `0x4b000000`, size `0x01700000`
- `q6_etr_region`: `0x4c800000`, size `0x00100000`

The verified nodes are added through a board-local `/reserved-memory`
overlay. Their source names and SHA-256 values are recorded.

## Acceptance criteria

- Both active-tree references are detected.
- MR5500/MX5500 definitions exist and agree.
- Provenance and hashes are recorded.
- The exact native ranges appear in the board patch.
- DTS preprocess, compile, decompile, and round-trip compile succeed.
- The unified DD-WRT patch applies cleanly.
- All Phase 28 integration and safety checks pass.

## Safety boundary

This remains source-only. It produces no firmware and accesses no router.
