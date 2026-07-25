# Phase 20 — DD-WRT IPQ5018 platform integration map

This phase is limited to the exact device:

- Xiaomi **Mi AIoT AX6000**
- model **RA72**
- Qualcomm **IPQ5018**
- board **MP03.1**

It is not for Xiaomi Mi Router AX6000 or Redmi AX6000.

Phase 19 found IPQ5018 source fragments but no complete target template.
Phase 20 examines the contents of the closest public DD-WRT build files,
configurations, kernel configurations, and reference-device Device Trees.

The audit ranks platform foundations and checks whether any IPQ5018 reference
device is connected to a non-DTS build or packaging definition.

The expected useful outcomes are:

- `IPQ5018_REFERENCE_DEVICE_BUILD_LINK_FOUND`;
- `IPQ60XX_PLATFORM_BASE_WITH_IPQ5018_DTS_NO_DEVICE_LINK`;
- `PARTIAL_PLATFORM_BASE_FOUND`;
- `PLATFORM_BASE_UNAVAILABLE`.

No firmware is built. No generated file is safe to flash.
