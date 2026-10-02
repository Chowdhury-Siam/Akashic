#!/usr/bin/env python3
"""Fail a Play release if its App Bundle is not 16 KB page-size compatible.

Checks the two independent requirements documented by Android:
  1. BundleConfig requests PAGE_ALIGNMENT_16K for generated APK packaging.
  2. Every bundled 64-bit ELF shared library has >=16 KB LOAD alignment and
     a 16 KB-aligned GNU_RELRO end, unless RELRO covers a whole LOAD segment.

The script intentionally validates the final AAB rather than trusting only
Gradle/NDK version declarations, so incompatible prebuilt plugin libraries are
caught before the artifact is uploaded to Google Play.
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys
import tempfile
import zipfile

PAGE_SIZE = 16 * 1024
REQUIRED_64_BIT_ABIS = {"arm64-v8a", "x86_64"}


class ValidationError(RuntimeError):
    pass


def run_checked(command: list[str], *, label: str) -> str:
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        details = (result.stderr or result.stdout).strip()
        raise ValidationError(f"{label} failed: {details or 'unknown error'}")
    return result.stdout


def check_bundle_config(aab: pathlib.Path, bundletool: pathlib.Path) -> None:
    run_checked(
        ["java", "-jar", str(bundletool), "validate", f"--bundle={aab}"],
        label="bundletool validate",
    )
    config = run_checked(
        ["java", "-jar", str(bundletool), "dump", "config", f"--bundle={aab}"],
        label="bundletool dump config",
    )
    if "PAGE_ALIGNMENT_16K" not in config:
        alignment_lines = [
            line.strip() for line in config.splitlines() if "ALIGNMENT" in line.upper()
        ]
        detail = "; ".join(alignment_lines) or "no page-alignment field was reported"
        raise ValidationError(
            "App Bundle does not request PAGE_ALIGNMENT_16K "
            f"({detail}). Google Play could generate 4 KB-aligned APKs."
        )
    print("[OK] BundleConfig requests PAGE_ALIGNMENT_16K")


def abi_for_entry(name: str) -> str | None:
    parts = pathlib.PurePosixPath(name).parts
    for index, part in enumerate(parts[:-2]):
        if part == "lib" and index + 2 < len(parts):
            abi = parts[index + 1]
            if abi in REQUIRED_64_BIT_ABIS and name.endswith(".so"):
                return abi
    return None


def parse_program_headers(output: str, library: str) -> None:
    load_alignments: list[int] = []
    load_ranges: list[tuple[int, int]] = []
    relro_ends: list[tuple[int, int]] = []

    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        fields = line.split()
        if not fields:
            continue

        if fields[0] == "LOAD":
            try:
                alignment = int(fields[-1], 0)
                virt_addr = int(fields[2], 0)
                mem_size = int(fields[5], 0)
            except (ValueError, IndexError) as exc:
                raise ValidationError(
                    f"Could not parse LOAD program header for {library}: {line}"
                ) from exc
            load_alignments.append(alignment)
            load_ranges.append((virt_addr, virt_addr + mem_size))

        elif fields[0] == "GNU_RELRO":
            # llvm-readelf -lW columns:
            # Type Offset VirtAddr PhysAddr FileSiz MemSiz Flg Align
            if len(fields) < 7:
                raise ValidationError(
                    f"Could not parse GNU_RELRO program header for {library}: {line}"
                )
            try:
                virt_addr = int(fields[2], 0)
                mem_size = int(fields[5], 0)
            except ValueError as exc:
                raise ValidationError(
                    f"Could not parse GNU_RELRO values for {library}: {line}"
                ) from exc
            relro_ends.append((virt_addr, mem_size))

    if not load_alignments:
        raise ValidationError(f"No ELF LOAD segments were found in {library}")

    too_small = [alignment for alignment in load_alignments if alignment < PAGE_SIZE]
    if too_small:
        rendered = ", ".join(hex(value) for value in too_small)
        raise ValidationError(
            f"{library} contains LOAD segments aligned below 16 KB: {rendered}"
        )

    for virt_addr, mem_size in relro_ends:
        relro_end = virt_addr + mem_size
        # Android's phdr_table_get_relro_min_align exempts a LOAD that is
        # entirely RELRO: rounding its end cannot protect writable tail data.
        # https://android.googlesource.com/platform/bionic/+/android16-qpr2-release/linker/linker_phdr_16kib_compat.cpp
        whole_load = any(
            start == virt_addr and end == relro_end
            for start, end in load_ranges
        )
        if relro_end % PAGE_SIZE != 0 and not whole_load:
            raise ValidationError(
                f"{library} has a GNU_RELRO end that is not 16 KB aligned: "
                f"(VirtAddr {hex(virt_addr)} + MemSiz {hex(mem_size)}) % 0x4000 "
                f"= {hex((virt_addr + mem_size) % PAGE_SIZE)}"
            )


def check_elf_libraries(
    aab: pathlib.Path, readelf: pathlib.Path
) -> dict[str, int]:
    counts = {abi: 0 for abi in REQUIRED_64_BIT_ABIS}

    with zipfile.ZipFile(aab) as archive, tempfile.TemporaryDirectory(
        prefix="yutaka-16kb-"
    ) as temp_dir:
        temp_root = pathlib.Path(temp_dir)
        entries = [
            info
            for info in archive.infolist()
            if not info.is_dir() and abi_for_entry(info.filename) is not None
        ]
        if not entries:
            raise ValidationError(
                "No arm64-v8a or x86_64 shared libraries were found in the final AAB."
            )

        for index, info in enumerate(entries):
            abi = abi_for_entry(info.filename)
            assert abi is not None
            counts[abi] += 1
            extracted = temp_root / f"{index}-{pathlib.PurePosixPath(info.filename).name}"
            extracted.write_bytes(archive.read(info))
            headers = run_checked(
                [str(readelf), "-lW", str(extracted)],
                label=f"llvm-readelf for {info.filename}",
            )
            parse_program_headers(headers, info.filename)
            print(f"[OK] {info.filename}: 16 KB ELF/RELRO alignment")

    if counts["arm64-v8a"] == 0:
        raise ValidationError(
            "The AAB does not contain arm64-v8a native libraries; Yutaka's Play build "
            "must retain 64-bit ARM support."
        )
    return counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--aab", required=True, type=pathlib.Path)
    parser.add_argument("--bundletool", required=True, type=pathlib.Path)
    parser.add_argument("--readelf", required=True, type=pathlib.Path)
    args = parser.parse_args()

    for label, path in (
        ("AAB", args.aab),
        ("bundletool", args.bundletool),
        ("llvm-readelf", args.readelf),
    ):
        if not path.is_file():
            raise ValidationError(f"{label} not found: {path}")

    check_bundle_config(args.aab, args.bundletool)
    counts = check_elf_libraries(args.aab, args.readelf)
    count_text = ", ".join(f"{abi}={count}" for abi, count in sorted(counts.items()))
    print(f"[OK] Yutaka Play AAB passed 16 KB page-size validation ({count_text})")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValidationError as exc:
        print(f"::error::16 KB page-size validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
