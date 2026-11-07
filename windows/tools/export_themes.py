#!/usr/bin/env python3
"""Export iOS theme colors to shared/themes.json.

Reads the Swift sources. Does not modify them. Run from anywhere:

    python windows/tools/export_themes.py
    python windows/tools/export_themes.py --check
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWIFT = ROOT / "Zalla"
OUT = ROOT / "shared" / "themes.json"

SOURCES = [
    "Zalla/ZallaTheme.swift",
    "Zalla/NewTabBackground.swift",
    "Zalla/SeasonalThemes.swift",
    "Zalla/ThemePacks.swift",
]


def brace_block(text: str, start: int) -> str:
    depth = 0
    begun = False
    for index in range(start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
            begun = True
        elif char == "}":
            depth -= 1
            if begun and depth == 0:
                return text[start : index + 1]
    raise SystemExit("Unbalanced braces while reading Swift.")


def extract_decl(text: str, signature: str) -> str:
    start = text.find(signature)
    if start < 0:
        raise SystemExit(f"Missing Swift declaration: {signature}")
    brace = text.find("{", start)
    return brace_block(text, brace)


def string_map(block: str) -> dict[str, str]:
    found = {}
    for match in re.finditer(r'case \.(\w+): return "([^"]*)"', block):
        found[match.group(1)] = match.group(2)
    return found


def case_list(block: str, name: str) -> list[str]:
    match = re.search(rf"static var {name}: \[ZallaThemeID\] \{{ \[(.+?)\] \}}", block, re.S)
    if not match:
        raise SystemExit(f"Missing theme list {name}")
    return re.findall(r"\.(\w+)", match.group(1))


def enum_order(block: str) -> list[str]:
    ids = []
    for line in block.splitlines():
        stripped = line.strip()
        if stripped.startswith("var ") or stripped.startswith("func ") or stripped.startswith("static "):
            break
        match = re.match(r"case (\w+)", stripped)
        if match:
            ids.append(match.group(1))
    if not ids:
        raise SystemExit("No theme ids found.")
    return ids


def unlock_ids(block: str) -> set[str]:
    body = extract_decl(block, "var requiresUnlock: Bool")
    unlocked = set()
    for line in body.splitlines():
        if "return true" not in line:
            continue
        unlocked.update(re.findall(r"\.(\w+)", line))
    return unlocked


def theme_colors(text: str) -> dict[str, dict]:
    body = extract_decl(text, "static func theme(for id: ZallaThemeID)")
    pattern = re.compile(
        r"case \.(\w+):\s*return ZallaTheme\(id: id, primary: hex\(\"([0-9A-Fa-f]{6})\"\), "
        r"bright: hex\(\"([0-9A-Fa-f]{6})\"\), deep: hex\(\"([0-9A-Fa-f]{6})\"\), "
        r"highlight: hex\(\"([0-9A-Fa-f]{6})\"\), gradientEnd: hex\(\"([0-9A-Fa-f]{6})\"\)"
        r"(?:, usesGradientAccent: (true|false))?\)"
    )
    colors = {}
    for match in pattern.finditer(body):
        colors[match.group(1)] = {
            "primary": match.group(2).upper(),
            "bright": match.group(3).upper(),
            "deep": match.group(4).upper(),
            "highlight": match.group(5).upper(),
            "gradientEnd": match.group(6).upper(),
            "usesGradientAccent": match.group(7) != "false",
        }
    return colors


def icon_raw_values(text: str) -> dict[str, str]:
    body = extract_decl(text, "enum AppIconPreference")
    raw = {}
    for match in re.finditer(r"case (?:`(\w+)`|(\w+)) = \"([^\"]+)\"", body):
        key = match.group(1) or match.group(2)
        raw[key] = match.group(3)
    return raw


def suggested_icons(block: str) -> dict[str, str]:
    body = extract_decl(block, "var suggestedAppIcon: AppIconPreference")
    return {match.group(1): match.group(2) for match in re.finditer(r"case \.(\w+): return \.(\w+)", body)}


def seasonal_windows(text: str) -> list[dict]:
    body = extract_decl(text, "static func window(for id: ZallaThemeID, endingIn year: Int)")
    windows = []
    simple = re.compile(
        r"case \.(\w+): return (prev|d)\((\d+), (\d+)\)\.\.\.(prev|d)\((\d+), (\d+)\)"
    )
    for match in simple.finditer(body):
        windows.append(
            {
                "id": match.group(1),
                "kind": "fixed",
                "start": {
                    "month": int(match.group(3)),
                    "day": int(match.group(4)),
                    "yearOffset": -1 if match.group(2) == "prev" else 0,
                },
                "end": {
                    "month": int(match.group(6)),
                    "day": int(match.group(7)),
                    "yearOffset": -1 if match.group(5) == "prev" else 0,
                },
            }
        )
    if "case .winter:" not in body:
        raise SystemExit("Winter window missing.")
    windows.append(
        {
            "id": "winter",
            "kind": "fixed",
            "start": {"month": 12, "day": 1, "yearOffset": -1},
            "end": {"month": 2, "day": 0, "yearOffset": 0, "dayMeaning": "last day of the month"},
        }
    )
    if "HolidayMath.easter" not in body or "HolidayMath.memorialDay" not in body:
        raise SystemExit("Computed seasonal windows missing.")
    windows.append(
        {
            "id": "easter",
            "kind": "computed",
            "rule": "westernEaster",
            "startOffsetDays": -14,
            "endOffsetDays": 1,
        }
    )
    windows.append(
        {
            "id": "memorialDay",
            "kind": "computed",
            "rule": "usMemorialDay",
            "startOffsetDays": -9,
            "endOffsetDays": 0,
        }
    )
    return windows


def new_tab_backgrounds(text: str) -> list[dict]:
    pattern = re.compile(
        r'NewTabPreset\(id: "([^"]+)", name: "([^"]+)", colors: \[([^\]]*)\], '
        r"style: \.(linear|radial), isDark: (true|false), pack: (nil|\"[^\"]+\")"
        r"(?:, decor: \.(\w+))?\)"
    )
    rows = []
    for match in pattern.finditer(text):
        colors = re.findall(r'"([0-9A-Fa-f]{6})"', match.group(3))
        pack = None if match.group(6) == "nil" else match.group(6).strip('"')
        rows.append(
            {
                "id": match.group(1),
                "name": match.group(2),
                "colors": [color.upper() for color in colors],
                "style": match.group(4),
                "isDark": match.group(5) == "true",
                "pack": pack,
                "decor": match.group(7) or "none",
                "requiresUnlock": pack is not None,
            }
        )
    return rows


def theme_packs(text: str) -> list[dict]:
    pattern = re.compile(
        r'ThemePack\(\s*'
        r'id: "([^"]+)",\s*'
        r'name: "([^"]+)",\s*'
        r'tagline: "([^"]+)",\s*'
        r"themeID: \.(\w+),\s*"
        r"icon: \.(\w+),\s*"
        r'backgroundPresetID: "([^"]+)",\s*'
        r"transition: \.(\w+),\s*"
        r'symbolName: "([^"]+)"\s*\)',
        re.S,
    )
    return [
        {
            "id": match.group(1),
            "name": match.group(2),
            "tagline": match.group(3),
            "themeId": match.group(4),
            "icon": match.group(5),
            "backgroundPresetId": match.group(6),
            "transition": match.group(7),
            "symbolName": match.group(8),
        }
        for match in pattern.finditer(text)
    ]


def build() -> dict:
    theme_text = (SWIFT / "ZallaTheme.swift").read_text(encoding="utf-8")
    background_text = (SWIFT / "NewTabBackground.swift").read_text(encoding="utf-8")
    seasonal_text = (SWIFT / "SeasonalThemes.swift").read_text(encoding="utf-8")
    pack_text = (SWIFT / "ThemePacks.swift").read_text(encoding="utf-8")

    enum_body = extract_decl(theme_text, "enum ZallaThemeID")
    order = enum_order(enum_body)
    names = string_map(extract_decl(enum_body, "var displayName: String"))
    primary = string_map(extract_decl(enum_body, "var primaryHex: String"))
    colors = theme_colors(theme_text)
    icons = suggested_icons(enum_body)
    icon_raw = icon_raw_values(theme_text)
    seasonal = set(case_list(enum_body, "seasonal"))
    pro = set(case_list(enum_body, "pro"))
    unlock = unlock_ids(enum_body)
    packs = theme_packs(pack_text)
    pack_ids = {pack["themeId"] for pack in packs}

    missing = [theme_id for theme_id in order if theme_id not in colors or theme_id not in names or theme_id not in primary]
    if missing:
        raise SystemExit(f"Incomplete theme export: {', '.join(missing)}")

    windows_by_id = {window["id"]: window for window in seasonal_windows(seasonal_text)}
    seasonal_order = case_list(enum_body, "seasonal")
    if set(windows_by_id) != set(seasonal_order):
        raise SystemExit("Seasonal windows do not match the seasonal theme list.")

    themes = []
    for theme_id in order:
        if theme_id in seasonal:
            group = "seasonal"
        elif theme_id in pro:
            group = "pro"
        elif theme_id in pack_ids:
            group = "pack"
        else:
            group = "accent"
        icon_case = icons[theme_id]
        themes.append(
            {
                "id": theme_id,
                "name": names[theme_id],
                "group": group,
                "requiresUnlock": theme_id in unlock,
                "seasonal": theme_id in seasonal,
                "usesGradientAccent": colors[theme_id]["usesGradientAccent"],
                "primaryHex": primary[theme_id].upper(),
                "colors": {
                    "primary": colors[theme_id]["primary"],
                    "bright": colors[theme_id]["bright"],
                    "deep": colors[theme_id]["deep"],
                    "highlight": colors[theme_id]["highlight"],
                    "gradientEnd": colors[theme_id]["gradientEnd"],
                },
                "icon": icon_raw[icon_case],
            }
        )

    document = {
        "version": 1,
        "note": "Theme colors exported from the iOS app. Both apps can read this file. Windows chooses its own starting theme in the desktop project.",
        "exportedFrom": SOURCES,
        "themes": themes,
        "seasonalWindows": [windows_by_id[theme_id] for theme_id in seasonal_order],
        "newTabBackgrounds": new_tab_backgrounds(background_text),
        "themePacks": packs,
    }
    if len(document["themes"]) < 30:
        raise SystemExit("Theme export looks truncated.")
    if len(document["seasonalWindows"]) != 12:
        raise SystemExit(f"Expected 12 seasonal windows, got {len(document['seasonalWindows'])}.")
    if len(document["newTabBackgrounds"]) < 40:
        raise SystemExit("New tab background export looks truncated.")
    if len(document["themePacks"]) < 8:
        raise SystemExit("Theme pack export looks truncated.")
    return document


def render(document: dict) -> str:
    return json.dumps(document, indent=2, ensure_ascii=False) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail if shared/themes.json is stale.")
    args = parser.parse_args()
    text = render(build())
    if args.check:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print("shared/themes.json does not match the iOS theme sources.", file=sys.stderr)
            print("Run: python windows/tools/export_themes.py", file=sys.stderr)
            return 1
        print("shared/themes.json matches the iOS theme sources.")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
