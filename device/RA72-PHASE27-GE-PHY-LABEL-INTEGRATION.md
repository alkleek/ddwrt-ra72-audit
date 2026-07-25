# Phase 27 GE PHY label-integration contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

## Phase 26 finding

Linux binding-symlink materialization succeeded and the RA72 dependency
closure converged. The C preprocessor also succeeded. DTC then stopped at:

`Label or path ge_phy not found`

The native DD-WRT `ipq5018.dtsi` already contains the internal IPQ5018
Gigabit PHY:

- compatible: `ethernet-phy-id004d.d0c0`
- MDIO address in `reg`: `7`
- reset: `GCC_GEPHY_MISC_ARES`

However, its node is written as `ethernet-phy@0` and has no `ge_phy` label.
Both the native DP node and the imported RA72 board source refer to
`&ge_phy`.

## Phase 27 correction

Identify exactly one existing internal GE PHY by its compatible and
`reg = <7>`. Rename only its node header to:

`ge_phy: ethernet-phy@7`

No PHY node is added or duplicated. The change to native `ipq5018.dtsi` is
included in the unified DD-WRT review patch.

## Acceptance criteria

- Exactly one matching existing internal GE PHY is found.
- Its label is `ge_phy` and unit address is `7`.
- The board's `&ge_phy` overlay remains intact.
- DTS preprocess, compile, decompile, and round-trip compile succeed.
- The unified DD-WRT patch applies cleanly and includes `ipq5018.dtsi`.
- All Phase 27 integration and safety checks pass.

## Safety boundary

This remains source-only. It produces no firmware and accesses no router.
