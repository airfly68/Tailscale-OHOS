#!/usr/bin/env python3
"""Deterministically extract readable content from saved HTML files.

Uses only the Python standard library and processes one input file at a time.
"""
from __future__ import annotations

import argparse
import html
import json
import re
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable

SKIP_TAGS = {"script", "style", "svg", "nav", "footer", "noscript", "template", "iframe", "canvas"}
BLOCK_TAGS = {"p", "li", "pre", "code", "blockquote", "td", "th", "figcaption", "dt", "dd"}
HEADING_TAGS = {f"h{i}" for i in range(1, 7)}
VOID_TAGS = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
WS = re.compile(r"\s+")
BASE64 = re.compile(r"data:(?:image|font|application)/[^,;]+(?:;[^,]*)?,[^\s'\"]+", re.I)
API_NAME = re.compile(r"\b(?:[A-Z][A-Za-z0-9_]*|[a-z_][A-Za-z0-9_]*\(\)|[a-z_][A-Za-z0-9_]*\.[A-Za-z0-9_]+)\b")


@dataclass
class Node:
    tag: str
    attrs: dict[str, str]
    children: list["Node"] = field(default_factory=list)
    data: list[str] = field(default_factory=list)

    def text(self) -> str:
        parts = self.data[:]
        for child in self.children:
            parts.append(child.text())
        return normalise(" ".join(parts))


def normalise(value: str) -> str:
    value = BASE64.sub("", html.unescape(value))
    return WS.sub(" ", value).strip()


class TreeBuilder(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = Node("document", {})
        self.stack = [self.root]

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        node = Node(tag, {k.lower(): v or "" for k, v in attrs})
        self.stack[-1].children.append(node)
        if tag not in VOID_TAGS:
            self.stack.append(node)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)
        if tag.lower() not in VOID_TAGS:
            self.handle_endtag(tag)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        for index in range(len(self.stack) - 1, 0, -1):
            if self.stack[index].tag == tag:
                del self.stack[index:]
                return

    def handle_data(self, data: str) -> None:
        if not any(node.tag in SKIP_TAGS for node in self.stack):
            self.stack[-1].data.append(data)


def excluded(node: Node) -> bool:
    if node.tag in SKIP_TAGS:
        return True
    attrs = " ".join((node.attrs.get("id", ""), node.attrs.get("class", ""), node.attrs.get("role", ""))).lower()
    return any(word in attrs for word in ("sidebar", "breadcrumb", "directory", "catalog", "toc", "header", "navigation", "navbar", "menu", "footer"))


def find_title(root: Node) -> str:
    def walk(nodes: Iterable[Node]) -> str:
        for node in nodes:
            if node.tag == "title":
                return node.text()
            result = walk(node.children)
            if result:
                return result
        return ""
    return walk(root.children)


def main_node(root: Node) -> Node:
    candidates: list[Node] = []
    def walk(node: Node) -> None:
        if node.tag in {"main", "article"}:
            candidates.append(node)
        for child in node.children:
            walk(child)
    walk(root)
    if candidates:
        return max(candidates, key=lambda n: len(n.text()))
    return root


def locator(text: str) -> str:
    return text[:240]


def classify(node: Node) -> str | None:
    if node.tag in HEADING_TAGS: return "heading"
    if node.tag == "p": return "paragraph"
    if node.tag in {"ul", "ol"}: return "list"
    if node.tag == "table": return "table"
    if node.tag == "pre": return "code"
    if node.tag == "img": return "image_alt"
    if node.tag in {"blockquote", "aside"}: return "note"
    attrs = " ".join((node.attrs.get("class", ""), node.attrs.get("role", ""))).lower()
    if any(word in attrs for word in ("warning", "alert", "notice", "tip", "note", "caution")): return "notice"
    return None


def table_text(node: Node) -> str:
    rows = []
    for row in node.children:
        if row.tag == "tr":
            cells = [child.text() for child in row.children if child.tag in {"td", "th"}]
            if cells: rows.append(" | ".join(cells))
        else:
            rows.extend(filter(None, table_text(row).split("\n")))
    return "\n".join(rows)


def extract(root: Node, filename: str) -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    headings: list[str] = []
    seen: set[tuple[str, str, str]] = set()

    def emit(kind: str, text: str) -> None:
        text = normalise(text) if kind != "table" else "\n".join(normalise(x) for x in text.splitlines() if normalise(x))
        if not text or len(text) < 2: return
        key = (" > ".join(headings), kind, text)
        if key in seen: return
        seen.add(key)
        result.append({"source_file": filename, "heading_path": " > ".join(headings), "content_type": kind,
                       "text": text, "locator": locator(text)})

    def walk(node: Node) -> None:
        if excluded(node): return
        kind = classify(node)
        if node.tag in HEADING_TAGS:
            level = int(node.tag[1])
            text = node.text()
            if text:
                del headings[level - 1:]
                headings.append(text)
                emit("heading", text)
            return
        if node.tag == "img":
            emit("image_alt", node.attrs.get("alt", ""))
            return
        if kind == "table":
            emit(kind, table_text(node)); return
        if kind == "list":
            items = [child.text() for child in node.children if child.tag == "li"]
            emit(kind, "\n".join(f"- {item}" for item in items)); return
        if kind == "code":
            emit(kind, node.text()); return
        if kind in {"paragraph", "note", "notice"}:
            emit(kind, node.text()); return
        for child in node.children:
            walk(child)
    walk(main_node(root))
    # Preserve API, component, property, and method identifiers as searchable units.
    identifiers: set[str] = set()
    for unit in list(result):
        if unit["content_type"] in {"heading", "image_alt"}:
            continue
        for name in API_NAME.findall(unit["text"]):
            if name in identifiers or len(name) < 3:
                continue
            identifiers.add(name)
            result.append({"source_file": filename, "heading_path": unit["heading_path"], "content_type": "api_name",
                           "text": name, "locator": locator(unit["text"])})
    return result


def markdown(title: str, units: list[dict[str, str]]) -> str:
    lines = [f"# {title or 'Untitled'}", ""]
    for unit in units:
        path = unit["heading_path"]
        if unit["content_type"] == "heading":
            lines.extend([f"## {unit['text']}", ""])
        else:
            if path: lines.extend([f"### {path}", ""])
            if unit["content_type"] == "code": lines.extend(["```", unit["text"], "```", ""])
            elif unit["content_type"] == "table": lines.extend([unit["text"], ""])
            else: lines.extend([unit["text"], ""])
    return "\n".join(lines)


def parse_file(path: Path, output: Path) -> tuple[dict[str, object], str | None]:
    raw = path.read_bytes()
    text = raw.decode("utf-8-sig", errors="replace")
    parser = TreeBuilder()
    try:
        parser.feed(text); parser.close()
        title = find_title(parser.root)
        units = extract(parser.root, path.name)
        stem = path.stem
        extracted = output / "extracted"; extracted.mkdir(parents=True, exist_ok=True)
        jsonl = extracted / f"{stem}.jsonl"
        md = extracted / f"{stem}.md"
        jsonl.write_text("".join(json.dumps(unit, ensure_ascii=False) + "\n" for unit in units), encoding="utf-8")
        md.write_text(markdown(title, units), encoding="utf-8")
        h1 = next((unit["text"] for unit in units if unit["content_type"] == "heading"), "")
        if not h1:
            h1 = title.split(" - ", 1)[0]
        return ({"file_name": path.name, "size_bytes": len(raw), "html_title": title, "main_heading": h1,
                 "status": "success", "unit_count": len(units), "text_bytes": sum(len(u["text"].encode("utf-8")) for u in units)}, None)
    except Exception as exc:  # manifest must record individual failures
        return ({"file_name": path.name, "size_bytes": len(raw), "html_title": "", "main_heading": "", "status": "failed", "unit_count": 0, "text_bytes": 0}, f"{type(exc).__name__}: {exc}")


def run(source: Path, output: Path) -> int:
    files = sorted([*source.rglob("*.html"), *source.rglob("*.htm")])
    records = []; failures = []
    for path in files:
        record, error = parse_file(path, output)
        records.append(record)
        if error: failures.append({"file_name": path.name, "reason": error})
    manifest = {"source_directory": str(source), "file_count": len(files), "success_count": len(files) - len(failures),
                "failure_count": len(failures), "total_extracted_text_bytes": sum(r["text_bytes"] for r in records),
                "documents": records, "failures": failures}
    output.mkdir(parents=True, exist_ok=True)
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# Document manifest", "", "| File | Size (bytes) | HTML title | Main heading | Status |", "| --- | ---: | --- | --- | --- |"]
    lines += [f"| {r['file_name']} | {r['size_bytes']} | {r['html_title'].replace('|', '\\|')} | {r['main_heading'].replace('|', '\\|')} | {r['status']} |" for r in records]
    if failures:
        lines += ["", "## Failures", ""] + [f"- {f['file_name']}: {f['reason']}" for f in failures]
    (output / "document-manifest.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0 if not failures else 1


if __name__ == "__main__":
    project = Path(__file__).resolve().parents[2]
    argp = argparse.ArgumentParser()
    argp.add_argument("--source", type=Path, default=project / "best-practices")
    argp.add_argument("--output", type=Path, default=project / "mesh-refactor")
    args = argp.parse_args()
    raise SystemExit(run(args.source, args.output))
