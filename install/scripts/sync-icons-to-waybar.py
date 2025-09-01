#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import datetime
import json
import os
import shutil
import sys
from pathlib import Path

try:
    import json5  # pip install json5
except ImportError:
    print("Error: json5 module not found. Install with: pip install json5", file=sys.stderr)
    sys.exit(1)

HOME = Path.home()
ICONS_FILE_DEFAULT = HOME / ".config/hypr/icons.map"
WAYBAR_CONFIG = HOME / ".config/waybar/config.jsonc"


class ScriptError(Exception):
    pass


def require_access(path: Path, read=True, write=False):
    if not path.exists():
        raise ScriptError(f"Error: file not found: {path}")
    if read and not os.access(path, os.R_OK):
        raise ScriptError(f"Error: file not readable: {path}")
    if write and not os.access(path, os.W_OK):
        raise ScriptError(f"Error: file not writable: {path}")


def ltrim(s: str) -> str:
    return s.lstrip()


def rtrim(s: str) -> str:
    return s.rstrip()


def trim(s: str) -> str:
    return s.strip()


def filter_lines(filepath: Path):
    # 주석/빈줄 제거 + 좌우 trim
    with filepath.open("r", encoding="utf-8") as f:
        for raw in f:
            # 유지: read -r / 마지막 줄 처리 등은 파이썬 파일 읽기로 자연스레 커버
            line = trim(raw)
            if not line:
                continue
            if line.startswith("#"):
                continue
            yield line


def to_tab_pairs(lines):
    # "key:value" → "key\tvalue" (내부 공백 제거)
    for line in lines:
        if ":" not in line:
            continue
        key, val = line.split(":", 1)
        key = trim(key)
        val = trim(val)
        # 내부 공백 제거 (원본 로직 유지)
        key = "".join(key.split())
        val = "".join(val.split())
        if not key or not val:
            continue
        yield f"{key}\t{val}"


def pairs_to_json_array_obj(tab_lines):
    # 탭이 여러개인 라인도 허용: 첫 요소=key, 마지막 요소=value
    arr = []
    for line in tab_lines:
        parts = line.split("\t")
        parts = [p for p in parts if p != ""]
        if len(parts) < 2:
            continue
        key = parts[0]
        value = parts[-1]
        arr.append({"key": key, "value": value})
    return arr


def json_array_obj_to_flat_object(arr):
    # 검증: object이며 key/value가 문자열인지
    bad = []
    for rec in arr:
        ok = (
            isinstance(rec, dict)
            and isinstance(rec.get("key", None), str)
            and isinstance(rec.get("value", None), str)
        )
        if not ok:
            bad.append(rec)
    if bad:
        # 최대 5개만 표시
        preview = bad[:5]
        raise ScriptError(f"Non-string key/value or invalid record: {preview}")
    # 마지막 등장 우선: 동일 키면 나중 값으로 덮어쓰되, 값 뒤에 공백을 덧붙임
    flat = {}
    for rec in arr:
        flat[rec["key"]] = rec["value"] + " "
    return flat


def build_window_rewrite_map_json(icons_file: Path):
    lines = list(filter_lines(icons_file))
    tab_pairs = list(to_tab_pairs(lines))
    arr = pairs_to_json_array_obj(tab_pairs)
    flat = json_array_obj_to_flat_object(arr)
    # pretty JSON으로 반환 (문자열 아님, 파이썬 dict)
    return flat


def read_jsonc_to_json(path: Path):
    # JSONC를 파싱해 Python 객체로 (json5 사용)
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json5.load(f)
    except Exception as e:
        raise ScriptError(f"json5 failed to parse {path}: {e}")
    return data


def ensure_object(v):
    return v if isinstance(v, dict) else {}


def inject_window_rewrite(doc: dict, the_map: dict):
    # .["hyprland/workspace"]를 객체로 강제, window-rewrite 교체
    root = doc if isinstance(doc, dict) else {}
    hw = ensure_object(root.get("hyprland/workspace", {}))
    hw["window-rewrite"] = the_map
    root["hyprland/workspace"] = hw
    return root


def pretty_json(obj) -> str:
    return json.dumps(obj, indent=2, ensure_ascii=False) + "\n"


def backup_file(path: Path) -> Path:
    ts = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    bak = Path(str(path) + f".{ts}.bak")
    shutil.copy2(path, bak)
    return bak


def main():
    parser = argparse.ArgumentParser(
        description="Sync icons map to Waybar hyprland/workspace.window-rewrite"
    )
    parser.add_argument(
        "icons_file",
        nargs="?",
        default=str(ICONS_FILE_DEFAULT),
        help=f"Icons map file (default: {ICONS_FILE_DEFAULT})",
    )
    parser.add_argument(
        "--config",
        default=str(WAYBAR_CONFIG),
        help=f"Waybar JSONC config path (default: {WAYBAR_CONFIG})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Do not write file; print result to stdout",
    )
    args = parser.parse_args()

    icons_path = Path(os.path.expanduser(args.icons_file))
    config_path = Path(os.path.expanduser(args.config))

    # 접근성 확인
    require_access(config_path, read=True, write=not args.dry_run)
    require_access(icons_path, read=True, write=False)

    # 1) 아이콘 맵 생성/정규화/검증
    the_map = build_window_rewrite_map_json(icons_path)
    map_json_compact = json.dumps(the_map, separators=(",", ":"), ensure_ascii=False)
    print(f"[OK ] map_json built and validated. length={len(map_json_compact)}", file=sys.stderr)

    # 2) JSONC → JSON 객체
    doc = read_jsonc_to_json(config_path)
    print("[OK ] json5 conversion done.", file=sys.stderr)

    # 3) 주입
    injected = inject_window_rewrite(doc, the_map)
    print("[OK ] jq inject done (python equivalent).", file=sys.stderr)

    # 4) 유효성 검증
    try:
        _ = json.dumps(injected)
    except Exception as e:
        raise ScriptError(f"Error: invalid JSON (after inject): {e}")
    print("[OK ] tmp_out is valid JSON", file=sys.stderr)

    # 5) pretty formatting
    formatted = pretty_json(injected)
    print(f"[OK ] pretty formatted. size={len(formatted.encode('utf-8'))} bytes", file=sys.stderr)

    if args.dry_run:
        # 표준출력으로 출력만
        sys.stdout.write(formatted)
        return

    # 6) 백업 후 교체
    bak = backup_file(config_path)
    print(f"[OK ] backup created: {bak}", file=sys.stderr)

    with config_path.open("w", encoding="utf-8") as f:
        f.write(formatted)

    print("[INFO] window-rewrite updated with pretty formatting.", file=sys.stderr)
    print(f"[INFO] Saved as: {config_path}", file=sys.stderr)
    print(f"[INFO] Backup: {bak}", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except ScriptError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


