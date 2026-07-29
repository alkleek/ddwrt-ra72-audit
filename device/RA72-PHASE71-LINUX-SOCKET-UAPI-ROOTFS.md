# RA72 Phase 71 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 70 evidence

The exact pinned Linux 6.12 NSS `linux/netlink.h` was copied into DD-WRT's
restricted userspace header tree. Its source and destination SHA-256 values
matched. The focused AArch64 uClibc compile then stopped at:

```text
error: unknown type name '__kernel_sa_family_t'
```

The pinned `linux/netlink.h` includes `linux/socket.h` for that type. The
userspace header tree therefore needs the matching pinned socket UAPI header,
not a hand-written typedef or a header from the GitHub runner.

## Phase 71 contract

The phase requires:

- the exact header source to be the pinned DD-WRT Linux 6.12 NSS UAPI tree;
- the destination to be DD-WRT's userspace `kernel_headers/include` tree;
- source and destination to be byte-for-byte identical;
- the copied `linux/socket.h` to define `__kernel_sa_family_t`;
- a focused AArch64 uClibc compile of the paired socket/netlink contract
  using that destination to pass;
- the bundled `usb_modeswitch/libusb` configure segment to detect
  `linux/netlink.h`;
- the exact Phase 69 missing-netlink failure to be absent;
- all earlier Phase 69 distutils and target OpenSSL contracts to remain valid.

If the build stops later, Phase 71 records the first new blocker instead of
claiming rootfs completion.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging remains blocked,
no router is contacted, and no output is boot-approved or flashable.
