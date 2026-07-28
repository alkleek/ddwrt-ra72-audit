# RA72 Phase 61 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 59 evidence

Phase 59 pinned public DD-WRT revision `65793`, synchronized the six stale
private-blkid basenames in checked-in `configure`, built
`libe2fsblkid.so`, and eliminated the Phase 57 missing-target error.

It then exposed this generated link state:

```text
LIBBLKID = $(LIB)/libe2fsblkid.so # $(LIBUUID)
LIBUUID = -luuid
```

Because the UUID dependency is after a comment marker, the actual blkid link
command contains private `libe2fsblkid.so` but not `-luuid`. The linker reports
that `libuuid.so.0` cannot be found and that `uuid_unparse` and `uuid_is_null`
are undefined.

## Phase 61 contract

Phase 60 proved its literal-comment assumption was incorrect. Phase 61 accepts
only the exact pinned `MCONFIG.in` template state:

- one private-blkid UUID dependency guarded by `@PRIVATE_LIBS_CMT@`;
- zero active equivalents.

It changes only:

```text
LIBBLKID = @LIBBLKID@ @PRIVATE_LIBS_CMT@ $(LIBUUID)
```

to:

```text
LIBBLKID = @LIBBLKID@ $(LIBUUID)
```

The workflow fails closed unless the replacement count is exactly one. It
also proves that `configure` and `configure.ac` remain byte-identical across
this correction and records the complete before/after and patch evidence.

After configuration it requires:

- generated `MCONFIG` uses private `libe2fsblkid`;
- the UUID dependency is active exactly once;
- `LIBUUID` resolves to `-luuid`;
- util-linux produced `libuuid.so`;
- the blkid link command places `libe2fsblkid.so` before `-luuid`;
- the Phase 59 UUID-link errors are absent.

No ABI, function signature, partition map, kernel, DTB, wireless profile,
boot container, or image recipe is changed by this phase.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved or flashable.
