#!/usr/bin/env python3

import argparse

def parse_sections(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    sections = {}
    current_section = None
    buffer = []
    in_section = False
    
    for line in lines:
        stripped = line.strip()
        if not in_section and stripped.endswith('{'):
            current_section = stripped[:-1].strip()
            in_section = True
            buffer = []
        elif in_section and stripped == '}':
            sections[current_section] = buffer
            in_section = False
            current_section = None
        elif in_section:
            buffer.append(line)
    
    return sections

def add_or_update_key_in_section(file_path, section, key, value):
    sections = parse_sections(file_path)
    
    if section not in sections:
        raise ValueError(f"Section {section} not found")
    
    lines = sections[section]
    key_line_idx = None
    
    for i, line in enumerate(lines):
        if line.strip().startswith(key):
            key_line_idx = i
            break
    
    if key_line_idx is not None:
        lines[key_line_idx] = f"    {key} = {value}\n"
    else:
        lines.append(f"    {key} = {value}\n")
    
    # 전체 파일을 다시 쓰기
    with open(file_path, 'r', encoding='utf-8') as f:
        full_lines = f.readlines()
    
    # 섹션 위치 다시 찾아 수정된 내용 반영
    out_lines = []
    in_section = False
    current_section = None
    
    i = 0
    while i < len(full_lines):
        line = full_lines[i]
        stripped = line.strip()
        if not in_section and stripped.startswith(section) and stripped.endswith('{'):
            out_lines.append(line)
            i += 1
            # 해당 섹션 내용을 새로 쓰기
            for new_line in lines:
                out_lines.append(new_line)
            # 기존 섹션 끝까지 건너뛰기
            while i < len(full_lines) and full_lines[i].strip() != '}':
                i += 1
            if i < len(full_lines):
                out_lines.append(full_lines[i])  # 닫는 중괄호
            in_section = False
            current_section = None
        else:
            out_lines.append(line)
        i += 1
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(out_lines)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add or update key=value in section of hypr config")
    parser.add_argument("file_path", help="Path to the hypr config file")
    parser.add_argument("section", help="Section name (e.g., general)")
    parser.add_argument("key", help="Key to add or update")
    parser.add_argument("value", help="Value to set for the key")

    args = parser.parse_args()

    add_or_update_key_in_section(args.file_path, args.section, args.key, args.value)
    print(f"Updated {args.key} in section [{args.section}] in {args.file_path}")
