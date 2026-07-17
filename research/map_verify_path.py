#!/usr/bin/env python3
"""
Map VSA / pkcs1_verify / VCIH symbols, sections, and compare-site candidates
in carved arm64 Mach-O object files from libocrstudiosdk-ios.a.

Authorized security research — descriptive map only (no patch generation).
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

OBJ_DIR = Path(
    r"C:\Users\NN\AppData\Local\Temp\claude"
    r"\D--Copy-ocr-studio-OCRStudioSDK-1-3-1-iOS-Trial"
    r"\1fa92c40-09fa-4e5f-aea8-0ca1eeeba1f0\scratchpad\obj"
)
OUT_JSON = Path(__file__).resolve().parent / "verify_path_map.json"

MH_MAGIC_64 = 0xFEEDFACF
LC_SYMTAB = 0x2
LC_DYSYMTAB = 0xB
LC_SEGMENT_64 = 0x19
LC_BUILD_VERSION = 0x32

# ARM64 Mach-O reloc types (subset)
ARM64_RELOC_UNSIGNED = 0
ARM64_RELOC_BRANCH26 = 2
ARM64_RELOC_PAGE21 = 3
ARM64_RELOC_PAGEOFF12 = 4
ARM64_RELOC_GOT_LOAD_PAGE21 = 5
ARM64_RELOC_GOT_LOAD_PAGEOFF12 = 6
ARM64_RELOC_ADDEND = 10

N_UNDF = 0x0
N_ABS = 0x2
N_SECT = 0xE
N_EXT = 0x01

# Expected embedded constants (from prior static analysis)
EXPECTED_HASH = bytes.fromhex("25159e611dfa6f5f077a732a01d17ead8cc9770b")
RSA_N = bytes.fromhex(
    "aa81d3f7eb1996c8ffd6d119451d60554d1d2924d2a6fd8e035dff9fcf29b3d5"
    "9046835374fab7dfa823c02c4f553ebe21e34277aa12c1cbf1df3e18d6e1eea6"
    "76f1628520b80db807e8b1a911c19797b7cd4c3c66eab2dab0daaafbe765c372"
    "b62d0825b8e2023a1fd2e88a22df338fa2e267a67bbf89613ac1d836cea1bf39"
)
CLIENT_ID = b"ocrstudio_arafatgroup_trial"
MARKER_PREFIX = b"se_client_id__"


def parse_macho(path: Path) -> dict:
    data = path.read_bytes()
    magic = struct.unpack_from("<I", data, 0)[0]
    if magic != MH_MAGIC_64:
        raise ValueError(f"{path.name}: not LE Mach-O 64 (magic={magic:#x})")

    cputype, cpusub, filetype, ncmds, sizeofcmds, flags, reserved = struct.unpack_from(
        "<IIIIIII", data, 4
    )
    sections: list[dict] = []
    symbols: list[dict] = []
    p = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, p)
        if cmd == LC_SEGMENT_64:
            segname = data[p + 8 : p + 24].split(b"\x00")[0].decode()
            vmaddr, vmsize, fileoff, filesize = struct.unpack_from("<QQQQ", data, p + 24)
            nsects = struct.unpack_from("<I", data, p + 64)[0]
            sp = p + 72
            for _s in range(nsects):
                sect = data[sp : sp + 80]
                sname = sect[0:16].split(b"\x00")[0].decode()
                seg = sect[16:32].split(b"\x00")[0].decode()
                saddr, ssize = struct.unpack_from("<QQ", sect, 32)
                soff, salign = struct.unpack_from("<II", sect, 48)
                reloff, nreloc = struct.unpack_from("<II", sect, 56)
                sections.append(
                    {
                        "segment": seg,
                        "section": sname,
                        "addr": saddr,
                        "size": ssize,
                        "file_off": soff,
                        "align": salign,
                        "reloff": reloff,
                        "nreloc": nreloc,
                    }
                )
                sp += 80
        elif cmd == LC_SYMTAB:
            symoff, nsyms, stroff, strsize = struct.unpack_from("<IIII", data, p + 8)
            strtab = data[stroff : stroff + strsize]
            for i in range(nsyms):
                e = symoff + i * 16
                n_strx, n_type, n_sect, n_desc, n_value = struct.unpack_from(
                    "<IBBHQ", data, e
                )
                end = strtab.find(b"\x00", n_strx)
                nm = strtab[n_strx:end].decode("ascii", "replace")
                kind = n_type & 0x0E
                symbols.append(
                    {
                        "name": nm,
                        "type": n_type,
                        "kind": {
                            N_UNDF: "undef",
                            N_ABS: "abs",
                            N_SECT: "sect",
                        }.get(kind, f"other({kind:#x})"),
                        "external": bool(n_type & N_EXT),
                        "sect_index": n_sect,
                        "value": n_value,
                        "desc": n_desc,
                    }
                )
        p += cmdsize

    return {
        "file": path.name,
        "path": str(path),
        "size": len(data),
        "cputype": cputype,
        "filetype": filetype,
        "sections": sections,
        "symbols": symbols,
        "raw": data,
    }


def parse_relocs(m: dict) -> list[dict]:
    """Resolve external relocations in __text to symbol names."""
    data = m["raw"]
    syms = m["symbols"]
    out: list[dict] = []
    type_names = {
        ARM64_RELOC_UNSIGNED: "UNSIGNED",
        ARM64_RELOC_BRANCH26: "BRANCH26",
        ARM64_RELOC_PAGE21: "PAGE21",
        ARM64_RELOC_PAGEOFF12: "PAGEOFF12",
        ARM64_RELOC_GOT_LOAD_PAGE21: "GOT_PAGE21",
        ARM64_RELOC_GOT_LOAD_PAGEOFF12: "GOT_PAGEOFF12",
        ARM64_RELOC_ADDEND: "ADDEND",
    }
    for s in m["sections"]:
        if s["section"] != "__text":
            continue
        for ri in range(s.get("nreloc") or 0):
            off = s["reloff"] + ri * 8
            r_address, r_info = struct.unpack_from("<II", data, off)
            r_symbolnum = r_info & 0xFFFFFF
            r_extern = (r_info >> 27) & 1
            r_type = (r_info >> 28) & 0xF
            if not r_extern:
                continue
            nm = syms[r_symbolnum]["name"] if r_symbolnum < len(syms) else f"?{r_symbolnum}"
            out.append(
                {
                    "vma": s["addr"] + r_address,
                    "type": type_names.get(r_type, str(r_type)),
                    "symbol": nm,
                    "hint": demangle_hint(nm),
                }
            )
    return out


def demangle_hint(name: str) -> str:
    """Best-effort readable hint for Itanium-style C++ mangled names we care about."""
    hints = {
        "VSA": "Verify Static Auth",
        "VEA": "Verify External Auth (caller-supplied hash)",
        "VCIH": "Verify Code Integrity Hash",
        "pkcs1_verify": "RSA PKCS#1 v1.5 verify",
        "get_hash": "SHA-1 via BearSSL",
        "CreateMarker": "Build se_client_id__ marker",
        "CreateStaticAuthData": "Build embedded const blob",
        "CreateActivationData": "priv || id",
        "pkcs1_sign": "RSA PKCS#1 sign (vendor-side)",
    }
    for k, v in hints.items():
        if k in name:
            return v
    return ""


def section_blob(m: dict, seg: str, sect: str) -> tuple[int, bytes] | None:
    for s in m["sections"]:
        if s["segment"] == seg and s["section"] == sect:
            off, sz = s["file_off"], s["size"]
            return s["addr"], m["raw"][off : off + sz]
    return None


def find_bytes(hay: bytes, needle: bytes) -> list[int]:
    out = []
    start = 0
    while True:
        i = hay.find(needle, start)
        if i < 0:
            break
        out.append(i)
        start = i + 1
    return out


def disasm_arm64_simple(code: bytes, base: int) -> list[dict]:
    """Minimal ARM64 decode for branch/compare-relevant opcodes only."""
    insns = []
    for i in range(0, len(code) - 3, 4):
        w = struct.unpack_from("<I", code, i)[0]
        addr = base + i
        kind = None
        detail = {}
        # BL (unconditional) imm26
        if (w & 0xFC000000) == 0x94000000:
            imm26 = w & 0x03FFFFFF
            if imm26 & 0x02000000:
                imm26 -= 0x04000000
            target = addr + imm26 * 4
            kind = "BL"
            detail = {"target": target}
        # B
        elif (w & 0xFC000000) == 0x14000000:
            imm26 = w & 0x03FFFFFF
            if imm26 & 0x02000000:
                imm26 -= 0x04000000
            target = addr + imm26 * 4
            kind = "B"
            detail = {"target": target}
        # RET
        elif w == 0xD65F03C0:
            kind = "RET"
        # CBZ Xt
        elif (w & 0xFF000000) == 0xB4000000:
            kind = "CBZ"
            imm19 = (w >> 5) & 0x7FFFF
            if imm19 & 0x40000:
                imm19 -= 0x80000
            detail = {"target": addr + imm19 * 4, "rt": w & 0x1F}
        # CBNZ
        elif (w & 0xFF000000) == 0xB5000000:
            kind = "CBNZ"
            imm19 = (w >> 5) & 0x7FFFF
            if imm19 & 0x40000:
                imm19 -= 0x80000
            detail = {"target": addr + imm19 * 4, "rt": w & 0x1F}
        # B.cond
        elif (w & 0xFF000010) == 0x54000000:
            kind = "B.cond"
            imm19 = (w >> 5) & 0x7FFFF
            if imm19 & 0x40000:
                imm19 -= 0x80000
            cond = w & 0xF
            detail = {"target": addr + imm19 * 4, "cond": cond}
        # CMP (SUBS Xd=XZR) — approximate: sf=1 opc=11
        elif (w & 0x7F00001F) == 0x6B00001F:
            kind = "CMP_reg"
        elif (w & 0x7F80001F) == 0x7100001F:
            kind = "CMP_imm"
            detail = {"imm": (w >> 10) & 0xFFF, "rn": (w >> 5) & 0x1F}
        # MOVZ / MOVK — useful for loading small constants into compare
        elif (w & 0xFF800000) == 0xD2800000:
            kind = "MOVZ"
            detail = {"imm": (w >> 5) & 0xFFFF, "rd": w & 0x1F, "hw": (w >> 21) & 0x3}
        elif (w & 0xFF800000) == 0xF2800000:
            kind = "MOVK"
            detail = {"imm": (w >> 5) & 0xFFFF, "rd": w & 0x1F, "hw": (w >> 21) & 0x3}
        # ADRP
        elif (w & 0x9F000000) == 0x90000000:
            kind = "ADRP"
            immlo = (w >> 29) & 0x3
            immhi = (w >> 5) & 0x7FFFF
            imm = (immhi << 2) | immlo
            if imm & 0x100000:
                imm -= 0x200000
            page = (addr & ~0xFFF) + (imm << 12)
            detail = {"page": page, "rd": w & 0x1F}
        # ADD Xd, Xn, #imm (for ADRP+ADD pair -> const address)
        elif (w & 0xFF000000) == 0x91000000:
            kind = "ADD_imm"
            detail = {
                "imm": (w >> 10) & 0xFFF,
                "rn": (w >> 5) & 0x1F,
                "rd": w & 0x1F,
                "shift": (w >> 22) & 0x3,
            }
        if kind:
            insns.append({"addr": addr, "off": i, "word": w, "kind": kind, **detail})
    return insns


def analyze_object(path: Path) -> dict:
    m = parse_macho(path)
    defined = [s for s in m["symbols"] if s["kind"] == "sect"]
    undef = [s for s in m["symbols"] if s["kind"] == "undef"]

    text = section_blob(m, "__TEXT", "__text")
    const = section_blob(m, "__DATA", "__const") or section_blob(m, "__TEXT", "__const")
    cstring = section_blob(m, "__TEXT", "__cstring")

    const_hits = {}
    if const:
        caddr, cbytes = const
        for label, needle in [
            ("EXPECTED_HASH", EXPECTED_HASH),
            ("RSA_N", RSA_N),
            ("CLIENT_ID", CLIENT_ID),
            ("MARKER_PREFIX", MARKER_PREFIX),
            ("RSA_E_bytes_00000003", bytes.fromhex("00000003")),
        ]:
            offs = find_bytes(cbytes, needle)
            const_hits[label] = [
                {"const_file_off": o, "vma": caddr + o, "len": len(needle)} for o in offs
            ]

    text_analysis = None
    if text:
        taddr, tbytes = text
        insns = disasm_arm64_simple(tbytes, taddr)
        # ADRP+ADD pairs that land in __const
        const_refs = []
        if const:
            caddr, cbytes = const
            cend = caddr + len(cbytes)
            by_rd_page = {}
            for insn in insns:
                if insn["kind"] == "ADRP":
                    by_rd_page[insn["rd"]] = insn["page"]
                elif insn["kind"] == "ADD_imm" and insn["rn"] in by_rd_page:
                    page = by_rd_page[insn["rn"]]
                    imm = insn["imm"] << (12 if insn["shift"] == 1 else 0)
                    target = page + imm
                    if caddr <= target < cend:
                        const_refs.append(
                            {
                                "at": insn["addr"],
                                "loads": target,
                                "const_offset": target - caddr,
                            }
                        )
        compare_like = [
            i
            for i in insns
            if i["kind"] in ("CMP_imm", "CMP_reg", "CBZ", "CBNZ", "B.cond")
        ]
        calls = [i for i in insns if i["kind"] == "BL"]
        text_analysis = {
            "text_vma": taddr,
            "text_size": len(tbytes),
            "insn_of_interest": len(insns),
            "const_address_loads": const_refs,
            "compare_branch_sites": compare_like,
            "bl_sites": calls,
        }

    # Map defined symbols to section
    for s in defined:
        idx = s["sect_index"]
        if 1 <= idx <= len(m["sections"]):
            sec = m["sections"][idx - 1]
            s["section"] = f"{sec['segment']},{sec['section']}"
            s["section_vma"] = sec["addr"]
            s["offset_in_section"] = s["value"] - sec["addr"]
        s["hint"] = demangle_hint(s["name"])

    for s in undef:
        s["hint"] = demangle_hint(s["name"])

    # Drop raw bytes from export
    result = {
        "file": m["file"],
        "size": m["size"],
        "sections": [
            {k: v for k, v in s.items()}
            for s in m["sections"]
        ],
        "defined_symbols": [
            {k: v for k, v in s.items() if k != "type"}
            for s in defined
        ],
        "undefined_symbols": [
            {"name": s["name"], "external": s["external"], "hint": s["hint"]}
            for s in undef
            if s["name"]
        ],
        "const_constant_hits": const_hits,
        "text_analysis": text_analysis,
        "text_relocs_external": parse_relocs(m),
        "cstrings": [],
    }
    if cstring:
        _, raw = cstring
        result["cstrings"] = [
            t.decode("ascii", "replace") for t in raw.split(b"\x00") if t
        ]
    return result


def summarize_for_report(objects: list[dict]) -> str:
    lines = [
        "# Verify-path binary map (arm64 object files)",
        "",
        "Source: carved arm64 slices from `libocrstudiosdk-ios.a`",
        f"(`ios-arm64_armv7_armv7s`). Generated by `research/map_verify_path.py`.",
        "",
        "**Scope:** descriptive symbol/offset map for remediation planning.",
        "Does **not** include patch bytes, bypass tooling, or forge utilities.",
        "",
    ]

    # Call chain overview from symbol names
    lines += [
        "## Call chain (from symbols + prior decompilation)",
        "",
        "```",
        "CreateSession(signature)",
        "  -> se::security::internal::VSA(const char*)     [static_auth.cpp.o]",
        "       -> se::security::pkcs1_verify(sig, PUBKEY, EXPECTED_HASH)  [verify.cpp.o]",
        "            -> hexstring_to_bytes(256 hex -> 128 bytes)",
        "            -> br_rsa_pkcs1_vrfy_get_default()",
        "            -> br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)",
        "            -> compare recovered digest[20] == EXPECTED_HASH[20]",
        "  (+ VCIH(): SHA-1(client_id) == same EXPECTED_HASH — integrity tie)",
        "```",
        "",
    ]

    for obj in objects:
        lines.append(f"## `{obj['file']}` ({obj['size']} bytes)")
        lines.append("")
        lines.append("### Sections")
        lines.append("")
        lines.append("| Segment | Section | VMA | Size | File off |")
        lines.append("|---------|---------|-----|------|----------|")
        for s in obj["sections"]:
            lines.append(
                f"| `{s['segment']}` | `{s['section']}` | "
                f"`0x{s['addr']:x}` | {s['size']} | `0x{s['file_off']:x}` |"
            )
        lines.append("")
        lines.append("### Defined symbols (patch-surface candidates)")
        lines.append("")
        lines.append("| Symbol | VMA | Sect | Off-in-sect | Role |")
        lines.append("|--------|-----|------|-------------|------|")
        for s in obj["defined_symbols"]:
            if not s["name"]:
                continue
            role = s.get("hint") or "—"
            sect = s.get("section", "?")
            ois = s.get("offset_in_section")
            ois_s = f"`0x{ois:x}`" if ois is not None else "—"
            lines.append(
                f"| `{s['name']}` | `0x{s['value']:x}` | `{sect}` | {ois_s} | {role} |"
            )
        lines.append("")
        interesting_undef = [
            u
            for u in obj["undefined_symbols"]
            if any(
                k in u["name"].lower()
                for k in (
                    "pkcs1",
                    "rsa",
                    "sha",
                    "br_",
                    "memcmp",
                    "hash",
                    "vsa",
                    "vea",
                    "vcih",
                    "verify",
                    "hex",
                )
            )
        ]
        if interesting_undef:
            lines.append("### Key undefined (outgoing calls)")
            lines.append("")
            for u in interesting_undef:
                hint = f" — {u['hint']}" if u["hint"] else ""
                lines.append(f"- `{u['name']}`{hint}")
            lines.append("")

        hits = obj.get("const_constant_hits") or {}
        if any(hits.values()):
            lines.append("### Embedded constants in `__const`")
            lines.append("")
            lines.append("| Constant | VMA(s) | Offset in `__const` |")
            lines.append("|----------|--------|---------------------|")
            for label, locs in hits.items():
                for loc in locs:
                    lines.append(
                        f"| `{label}` | `0x{loc['vma']:x}` | `+0x{loc['const_offset'] if 'const_offset' in loc else loc['const_file_off']:x}` |"
                    )
            lines.append("")

        ta = obj.get("text_analysis")
        if ta:
            lines.append("### `__text` control-flow / compare sites")
            lines.append("")
            lines.append(
                f"Text VMA `0x{ta['text_vma']:x}`, size {ta['text_size']} bytes."
            )
            lines.append("")
            if ta["const_address_loads"]:
                lines.append("**ADRP+ADD loads into `__const`** (pubkey / hash refs):")
                lines.append("")
                lines.append("| At (text VMA) | Loads VMA | `__const` offset |")
                lines.append("|---------------|-----------|------------------|")
                for r in ta["const_address_loads"]:
                    lines.append(
                        f"| `0x{r['at']:x}` | `0x{r['loads']:x}` | `+0x{r['const_offset']:x}` |"
                    )
                lines.append("")
            if ta["compare_branch_sites"]:
                lines.append(
                    "**Compare / conditional-branch sites** (integrity & null checks; "
                    "digest compare may be inlined or via `memcmp`):"
                )
                lines.append("")
                lines.append("| VMA | Kind | Detail |")
                lines.append("|-----|------|--------|")
                for c in ta["compare_branch_sites"]:
                    extra = {k: v for k, v in c.items() if k not in ("addr", "off", "word", "kind")}
                    detail = ", ".join(
                        f"{k}={v:#x}" if isinstance(v, int) else f"{k}={v}"
                        for k, v in extra.items()
                    )
                    lines.append(f"| `0x{c['addr']:x}` | `{c['kind']}` | {detail or '—'} |")
                lines.append("")
            if ta["bl_sites"]:
                lines.append("**BL call sites** (targets are relocatable in `.o`; resolve via linker):")
                lines.append("")
                for c in ta["bl_sites"]:
                    lines.append(f"- `0x{c['addr']:x}` → provisional target `0x{c['target']:x}`")
                lines.append("")

        if obj.get("cstrings"):
            lines.append("### C-strings")
            lines.append("")
            for s in obj["cstrings"]:
                lines.append(f"- `{s}`")
            lines.append("")

    lines += [
        "## Patch-surface summary (for vendor hardening — not exploit steps)",
        "",
        "| Site class | Where | Why it matters to OEM |",
        "|------------|-------|------------------------|",
        "| Entry gate | `VSA` / `VEA` in `static_auth.cpp.o` | Single offline auth entry; callers in session create |",
        "| Crypto core | `pkcs1_verify` in `verify.cpp.o` | RSA verify + digest compare |",
        "| Integrity twin | `VCIH` in `static_auth.cpp.o` | Same expected hash as auth; weak if both patched |",
        "| Embedded material | `__const` pubkey `n`, `e=3`, EXPECTED_HASH | Fixed offsets; must rotate with crypto upgrade |",
        "| BearSSL vrfy | undef `br_rsa_pkcs1_vrfy*` | hash_oid=NULL / raw SHA-1 mode |",
        "",
        "## Reminder",
        "",
        "Offsets above are **within relocatable object files** (VMAs typically start at 0).",
        "In a linked app / static archive member they shift; use symbol names for stable references.",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    targets = [
        "static_auth.cpp.o.arm64.macho",
        "verify.cpp.o.arm64.macho",
        "hashing.cpp.o.arm64.macho",
    ]
    objects = []
    for name in targets:
        path = OBJ_DIR / name
        if not path.is_file():
            print(f"MISSING: {path}", file=sys.stderr)
            continue
        print(f"Analyzing {name}...")
        objects.append(analyze_object(path))

    OUT_JSON.write_text(json.dumps(objects, indent=2), encoding="utf-8")
    report = summarize_for_report(objects)
    # Do not overwrite the curated VERIFY_PATH_MAP.md (hand-edited for disclosure).
    report_path = Path(__file__).resolve().parent / "VERIFY_PATH_MAP.auto.md"
    report_path.write_text(report, encoding="utf-8")
    print(f"Wrote {OUT_JSON}")
    print(f"Wrote {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
