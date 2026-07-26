from __future__ import annotations

import pathlib
import re
import sys


def read(path: str) -> str:
    target = pathlib.Path(path)
    if not target.exists():
        return ""
    return target.read_text(encoding="utf-8", errors="replace")


(
    rootfs_path,
    stage_path,
    validation_status_path,
    busybox_type_path,
    unexpected_flashable_path,
    output_path,
) = sys.argv[1:]

rootfs = pathlib.Path(rootfs_path)
stage = pathlib.Path(stage_path)
validation_status = read(validation_status_path)
busybox_type = read(busybox_type_path)
unexpected_flashable = read(unexpected_flashable_path).strip()


def any_exists(*names: str) -> bool:
    return any((stage / name).exists() for name in names)


checks = {
    "rootfs_file_exists": rootfs.is_file(),
    "rootfs_file_is_nontrivial":
        rootfs.is_file() and rootfs.stat().st_size > 1024 * 1024,
    "rootfs_fits_single_ra72_rootfs_partition":
        rootfs.is_file() and rootfs.stat().st_size < 36 * 1024 * 1024,
    "squashfs_superblock_valid":
        "superblock_status=0" in validation_status,
    "rootfs_extraction_passed":
        "extraction_status=0" in validation_status,
    "rootfs_stage_exists": stage.is_dir(),
    "rootfs_has_init":
        any_exists("sbin/init", "etc/preinit", "init"),
    "rootfs_has_shell":
        any_exists("bin/sh", "bin/ash"),
    "rootfs_has_busybox":
        any_exists("bin/busybox", "sbin/busybox"),
    "rootfs_has_etc": (stage / "etc").is_dir(),
    "rootfs_has_sbin": (stage / "sbin").is_dir(),
    "rootfs_has_ddwrt_web_files":
        any_exists("www", "www/index.asp", "www/index.html"),
    "busybox_is_arm64":
        bool(re.search(r"(?:ARM aarch64|ARM64|AArch64)", busybox_type,
                       re.IGNORECASE)),
    "no_flashable_container_was_built": not unexpected_flashable,
}

output = pathlib.Path(output_path)
output.write_text(
    "\n".join(
        f"{name}={'PASS' if value else 'FAIL'}"
        for name, value in sorted(checks.items())
    )
    + "\n",
    encoding="utf-8",
)

failed = [name for name, value in checks.items() if not value]
if failed:
    print("Failed Phase 38 checks:", ", ".join(failed))
    raise SystemExit(1)

print(
    "Phase 38 DD-WRT RA72 userspace/rootfs checks passed: "
    f"{len(checks)}/{len(checks)}"
)
