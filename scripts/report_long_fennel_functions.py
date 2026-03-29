#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
from dataclasses import dataclass


FN_START_RE = re.compile(r"\(fn\s+([^\s\[\]()]+)")
STRING_RE = re.compile(r'"(?:\\.|[^"\\])*"')


@dataclass
class FunctionSpan:
    path: pathlib.Path
    name: str
    start_line: int
    end_line: int

    @property
    def line_count(self) -> int:
        return self.end_line - self.start_line + 1


def strip_line_for_parens(line: str) -> str:
    no_strings = STRING_RE.sub('""', line)
    comment_at = no_strings.find(";")
    if comment_at >= 0:
        no_strings = no_strings[:comment_at]
    return no_strings


def scan_functions(path: pathlib.Path) -> list[FunctionSpan]:
    spans: list[FunctionSpan] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    current_name: str | None = None
    current_start: int | None = None
    depth = 0

    for lineno, raw in enumerate(lines, start=1):
        line = strip_line_for_parens(raw)

        if current_name is None:
            match = FN_START_RE.search(line)
            if match:
                current_name = match.group(1)
                current_start = lineno
                start_idx = match.start()
                frag = line[start_idx:]
                depth = frag.count("(") - frag.count(")")
                if depth <= 0 and current_start is not None:
                    spans.append(FunctionSpan(path, current_name, current_start, lineno))
                    current_name = None
                    current_start = None
                    depth = 0
            continue

        depth += line.count("(") - line.count(")")
        if depth <= 0 and current_start is not None:
            spans.append(FunctionSpan(path, current_name, current_start, lineno))
            current_name = None
            current_start = None
            depth = 0

    return spans


def iter_fennel_files(root: pathlib.Path) -> list[pathlib.Path]:
    return sorted(p for p in root.rglob("*.fnl") if p.is_file())


def main() -> int:
    parser = argparse.ArgumentParser(description="Report long Fennel functions.")
    parser.add_argument("paths", nargs="*", default=["fnl"], help="Directories/files to scan")
    parser.add_argument("--min-lines", type=int, default=40, help="Minimum function length to report")
    parser.add_argument("--top", type=int, default=50, help="Maximum number of functions to print")
    args = parser.parse_args()

    candidates: list[FunctionSpan] = []
    for raw_path in args.paths:
        path = pathlib.Path(raw_path)
        if path.is_file() and path.suffix == ".fnl":
            candidates.extend(scan_functions(path))
        elif path.is_dir():
            for file_path in iter_fennel_files(path):
                candidates.extend(scan_functions(file_path))

    candidates = [span for span in candidates if span.line_count >= args.min_lines]
    candidates.sort(key=lambda span: (-span.line_count, str(span.path), span.start_line))

    for span in candidates[: args.top]:
        print(f"{span.line_count:>4}  {span.path}:{span.start_line}-{span.end_line}  {span.name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
