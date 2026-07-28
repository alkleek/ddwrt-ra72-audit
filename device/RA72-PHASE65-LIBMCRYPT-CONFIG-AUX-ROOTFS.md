# RA72 Phase 65 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 64 evidence

The Phase 64 contracts confirmed that the isolated util-linux `blkid.pc`,
`uuid.pc`, and DD-WRT in-tree `libudev.pc` metadata all passed. Btrfsprogs
configure reported both `checking for blkid... yes` and
`checking for libudev... yes`.

The next fatal operation entered `src/router/libmcrypt`. Its checked-in
`config.sub` rejected the valid target tuple `aarch64-linux` because that
helper predates AArch64 recognition. The failure occurred before compilation
of libmcrypt and is independent of the RA72 device tree, kernel, Ethernet, or
wireless work.

## Phase 65 contract

Phase 65 discovers the maintained Ubuntu `config.guess` and `config.sub`
copies already used by the earlier verified libsodium correction. It records
the original libmcrypt helpers, installs the maintained copies with mode
`0755`, and requires:

- source and destination helpers to be present;
- destination helpers to be executable;
- each destination to be byte-identical to its recorded host source;
- `config.sub aarch64-linux` to succeed;
- `config.sub aarch64-uclibc-linux` to succeed;
- `config.guess` to succeed;
- the exact Phase 64 “machine aarch64 not recognized” message to be absent
  from the corrected helper output.

The correction is deliberately limited to Autotools platform recognition.
No libmcrypt algorithm, ABI, source implementation, or build option is
changed.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging commands are
blocked, no router is contacted, and no output is boot-approved or flashable.
