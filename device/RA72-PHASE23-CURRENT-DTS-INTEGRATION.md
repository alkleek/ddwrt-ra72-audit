# Phase 23 current-DTS integration contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

## Corrected dependency rule

Phase 22 stopped before compilation because it required `q6_region` and
`q6_etr_region` unconditionally. Phase 23 derives the requirement from the
current imported RA72 DTS:

1. detect whether the board DTS references each label;
2. if referenced, verify that the native DD-WRT base defines it;
3. if not referenced, classify it as not required;
4. stop safely if any actual reference remains unresolved.

No reserved-memory address or size is guessed or injected.

## Acceptance criteria

- Current RA72 DTS dependencies resolve against the native DD-WRT base.
- Preprocessing and DTB compilation succeed.
- DTB decompilation and round-trip compilation succeed.
- The DTB and image recipe are integrated in temporary Makefiles.
- The unified patch applies cleanly to an untouched source layout.
- All identity, Ethernet topology, recipe, NAND geometry, and safety checks
  pass.

## Safety boundary

This remains a source-only compile audit. It creates no DD-WRT firmware and
does not contact or modify any router.
