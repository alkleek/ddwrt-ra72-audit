# RA72 Phase 13 Q6 reserved-memory compile contract

Scope is restricted to Xiaomi Mi AIoT AX6000 model RA72, Qualcomm IPQ5018,
board MP03.1.

Phase 13 must:

1. use a verified OpenWrt source reference;
2. locate exact definitions of `q6_region` and `q6_etr_region`;
3. record source paths and hashes;
4. inject only the exact definitions into a temporary DD-WRT native base;
5. preprocess, compile, decompile, and round-trip compile the Device Tree;
6. stop safely if any definition is unavailable.

Phase 13 must not:

- invent reserved-memory addresses or sizes;
- use `dtc -f`;
- build firmware;
- write to a router;
- claim DD-WRT compatibility.
