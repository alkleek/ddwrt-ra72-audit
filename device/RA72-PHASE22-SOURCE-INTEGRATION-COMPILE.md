# Phase 22 source-integration contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

## Inputs established by earlier phases

- DD-WRT platform integration point: `src/router/Makefile.ipq60xx`
- IPQ5018 root filesystem: `root.ipq5018`
- DD-WRT FIT/ITB load and entry address: `0x41000000`
- NAND geometry: 128 KiB PEB and 2048-byte minimum I/O
- RA72 network topology: QCA8337 LAN switch and QCA8081 WAN PHY
- Verified RA72 reference DTS and exact Q6 reserved-memory definitions

## Phase 22 acceptance criteria

- The exact RA72 DTS preprocesses and compiles against the DD-WRT IPQ5018
  device-tree base.
- The compiled DTB can be decompiled and compiled again.
- The Qualcomm DTS Makefile registers `ipq5018-xiaomi-ra72.dtb`.
- The temporary `Makefile.ipq60xx` contains the Phase 21 RA72 recipe.
- The generated patch applies cleanly to an untouched temporary source layout.
- The inserted recipe contains no Linksys wrapper and no flash command.

## Non-goals

Phase 22 does not build a kernel, root filesystem, FIT image, UBI image, or
flashable DD-WRT firmware. It does not access a router. Passing this phase means
only that the source integration and DTS compile contract are internally
consistent.
