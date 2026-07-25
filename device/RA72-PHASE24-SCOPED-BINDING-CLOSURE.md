# Phase 24 scoped-binding contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

## Corrected rule

Do not inspect binding includes from unrelated Qualcomm boards. Starting from
the imported RA72 DTS, recursively follow:

1. its local DTS/DTSI includes;
2. the local includes of those files;
3. the `dt-bindings` headers reached by that exact chain;
4. nested includes used by those binding headers.

Missing required public binding headers may be fetched into the temporary
compile tree. A failure identifies the exact required header and stops safely.

## Acceptance criteria

- The RA72-only dependency closure converges.
- No required RA72 source include is unresolved.
- The RA72 DTS preprocesses and compiles.
- The DTB decompiles and round-trip compiles.
- The temporary DD-WRT source patch applies cleanly.
- All identity, Ethernet, recipe, NAND, dependency, and safety checks pass.

## Safety boundary

This is a source-only audit. It creates no firmware and never accesses a
router, NAND, SSH, or UART.
