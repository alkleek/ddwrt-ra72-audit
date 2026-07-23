# Xiaomi Mi AIoT AX6000 RA72 runtime hardware contract

Source: the live OpenWrt FDT captured from a working Xiaomi Mi AIoT AX6000,
model RA72. The raw DTB is intentionally not stored in this repository because
device-specific values may be present.

## Identity

- Product: Xiaomi Mi AIoT AX6000
- Model number: RA72
- SoC: Qualcomm IPQ5018
- Board: MP03.1
- OpenWrt compatible strings: `xiaomi,ax6000`, `qcom,ipq5018`
- OpenWrt internal device identifier: `xiaomi_ax6000`

The internal identifier must never be interpreted as support for the different
Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Memory and reserved regions

- Main RAM begins at `0x40000000`
- `0x4a400000-0x4adfffff` is reserved for trusted firmware/boot components
- `0x4b000000-0x4cafffff` is reserved for WCSS
- No RAM load address is approved by this contract

## Ethernet

- MDIO controllers: `0x88000` and `0x90000`
- QCA8337 switch: MDIO address `0x11`
- LAN ports: three user ports, exposed as `lan1`, `lan2`, `lan3`
- Switch CPU/uplink port: port 4, GMII
- WAN PHY: Qualcomm QCA8081 at MDIO address `0x08`
- PHY reset GPIO: 39
- Datapath nodes: NSS-DP `dp1` and `dp2`

## Wi-Fi and calibration

- Internal IPQ5018 Wi-Fi radio
- PCIe radio on controller at `0x80000000` using the ath10k family
- PCIe radio on controller at `0xa0000000`, Qualcomm device `17cb:1104`,
  using the ath11k family
- ART partition offset: `0x780000`, size: `0x100000`
- ART supplies calibration and MAC data and must never be overwritten

## NAND and controls

- SPI NAND controller: `0x79b0000`
- NAND size: 128 MiB
- Erase block: 128 KiB
- Page size: 2 KiB
- Reset button GPIO: 38
- LED GPIO range observed: 23 through 28

## Safety meaning

This contract is sufficient to audit and scaffold a DD-WRT device definition.
It is not proof of a bootable image and does not approve any NAND write.
The exact bootloader-safe RAM load address and accepted image container remain
unverified. UART remains the emergency recovery path.
