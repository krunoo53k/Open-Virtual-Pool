#!/usr/bin/env python3
"""Heuristic composition lint for Godot 4 projects (GDScript and .tscn).

Usage:
    python lint_composition.py [PROJECT_DIR] [--strict] [--json]

Exit code: 0 = no errors (warnings allowed), 1 = at least one error
(or any warning with --strict).

Suppress a justified exception with a comment on the same or previous line:
    # lint-ignore: no-parent-reach (reason)
or for a whole file, anywhere in it:
    # lint-ignore-file: script-too-long (reason)

These are heuristics. They catch the common drift (big scripts, nodes built in
code, reaching through the tree, raw keys) and are not a substitute for the
scene plan.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path

SKIP_DIRS = {".godot", ".git", "addons", "target", "node_modules", ".import", "build"}

NODE_CLASSES = (
    r"Node|Node2D|Node3D|Control|CanvasLayer|Label|Button|ColorRect|TextureRect|Panel|"
    r"Camera2D|Camera3D|MeshInstance2D|MeshInstance3D|Sprite2D|Sprite3D|Area2D|Area3D|"
    r"CollisionShape2D|CollisionShape3D|DirectionalLight3D|OmniLight3D|SpotLight3D|Timer|"
    r"AudioStreamPlayer\w*|AnimationPlayer|RigidBody[23]D|StaticBody[23]D|CharacterBody[23]D|"
    r"VBoxContainer|HBoxContainer|MarginContainer|GridContainer|WorldEnvironment"
)

RE_NEW_NODE = re.compile(r"\b(?:" + NODE_CLASSES + r")\.new\(\)")
RE_FUNC = re.compile(r"^func\s+(\w+)")
RE_VAR = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*var\s+([A-Za-z]\w*)")
RE_CONST = re.compile(r"^const\s+\w+")
RE_SIGNAL = re.compile(r"^signal\s+(\w+)\s*(?:\((.*)\))?")
RE_PARENT = re.compile(r"\bget_parent\(\)")
RE_UP_PATH = re.compile(r"""(?:get_node(?:_or_null)?\(\s*["'](?:\.\./|/root)|\$["']?(?:\.\./|/root))""")
RE_TREE = re.compile(r"get_tree\(\)\.(?:root|current_scene)\b")
RE_GROUP = re.compile(r"get_tree\(\)\.get_nodes_in_group")
RE_RAW_KEY = re.compile(r"\b(?:Input\.is_key_pressed|InputEventKey)\b|\.(?:physical_)?keycode\b")
RE_CLI = re.compile(r"\bOS\.get_cmdline")
RE_PRELOAD_GD = re.compile(r"""preload\(\s*["']res://[^"']+\.gd["']\s*\)""")
RE_TEST_COMMENT = re.compile(r"^\s*#.*\b(?:the tests?|a test|play ?tests?|for tests?|in tests?)\b", re.I)
RE_STATE_MATCH = re.compile(r"^\s*match\s+(?:phase|state|mode|status)\b")
RE_IGNORE = re.compile(r"lint-ignore:\s*([\w\-, ]+)")
RE_IGNORE_FILE = re.compile(r"lint-ignore-file:\s*([\w\-, ]+)")
VAGUE_SUFFIXES = ("_manager", "_controller", "_handler", "_system")


@dataclass
class Finding:
    path: str
    line: int
    level: str  # ERROR | WARN
    rule: str
    message: str


class Config:
    def __init__(self, a: argparse.Namespace):
        self.max_lines_warn = a.max_lines
        self.max_lines_error = a.max_lines * 2
        self.max_funcs_warn = 12
        self.max_funcs_error = 25
        self.max_func_len = 40
        self.max_public_vars = 8
        self.max_consts = 6
        self.max_new_warn = 2
        self.max_new_error = 6
        self.max_add_child = 4
        self.max_nodes_warn = 15
        self.max_nodes_error = 30
        self.child_script_lines = 60
        self.composer_script_lines = 60
        self.report_cap = 3  # per rule per file


class FileReport:
    """Collects findings for one file and applies ignores and the per-rule cap."""

    def __init__(self, path: Path, rel: str, lines: list[str]):
        self.rel = rel
        self.lines = lines
        self.items: list[Finding] = []
        self.file_ignores: set[str] = set()
        for l in lines:
            m = RE_IGNORE_FILE.search(l)
            if m:
                self.file_ignores.update(x.strip() for x in m.group(1).split(","))

    def _ignored(self, rule: str, line: int) -> bool:
        if rule in self.file_ignores:
            return True
        for ln in (line, line - 1):
            if 1 <= ln <= len(self.lines):
                m = RE_IGNORE.search(self.lines[ln - 1])
                if m and rule in [x.strip() for x in m.group(1).split(",")]:
                    return True
        return False

    def add(self, rule: str, line: int, level: str, msg: str) -> None:
        if not self._ignored(rule, line):
            self.items.append(Finding(self.rel, line, level, rule, msg))

    def capped(self, cap: int) -> list[Finding]:
        by_rule: dict[str, list[Finding]] = defaultdict(list)
        for f in self.items:
            by_rule[f.rule].append(f)
        out: list[Finding] = []
        for rule, fs in by_rule.items():
            out.extend(fs[:cap])
            if len(fs) > cap:
                last = fs[-1]
                out.append(Finding(last.path, last.line, last.level, rule, f"...and {len(fs) - cap} more '{rule}' in this file"))
        return sorted(out, key=lambda f: (f.line, f.rule))


def code_lines(lines: list[str]) -> int:
    return sum(1 for l in lines if l.strip() and not l.strip().startswith("#"))


def lint_gd(path: Path, rel: str, cfg: Config) -> tuple[list[Finding], int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    rep = FileReport(path, rel, lines)
    n = code_lines(lines)

    if n > cfg.max_lines_error:
        rep.add("script-too-long", 1, "ERROR", f"{n} code lines (limit {cfg.max_lines_error}). Split by responsibility into scenes.")
    elif n > cfg.max_lines_warn:
        rep.add("script-too-long", 1, "WARN", f"{n} code lines (budget {cfg.max_lines_warn}). Split by responsibility.")

    stem = path.stem.lower()
    if stem.endswith(VAGUE_SUFFIXES):
        rep.add("vague-name", 1, "WARN", f"'{path.stem}' sounds like a catch-all. Name the one job.")

    funcs: list[tuple[str, int, int]] = []  # name, start, length
    cur = None
    for i, l in enumerate(lines, 1):
        s = l.strip()
        if cur is not None:
            if s and not l[0].isspace():  # a new top-level line ends the body
                funcs.append((cur[0], cur[1], cur[2]))
                cur = None
            elif s and not s.startswith("#"):
                cur[2] += 1
        m = RE_FUNC.match(l)
        if m:
            if cur is not None:
                funcs.append((cur[0], cur[1], cur[2]))
            cur = [m.group(1), i, 1]
    if cur is not None:
        funcs.append((cur[0], cur[1], cur[2]))

    if len(funcs) > cfg.max_funcs_error:
        rep.add("too-many-funcs", 1, "ERROR", f"{len(funcs)} functions (limit {cfg.max_funcs_error}).")
    elif len(funcs) > cfg.max_funcs_warn:
        rep.add("too-many-funcs", 1, "WARN", f"{len(funcs)} functions (budget {cfg.max_funcs_warn}).")
    for name, start, length in funcs:
        if length > cfg.max_func_len:
            rep.add("long-func", start, "WARN", f"func {name}() is {length} lines (budget {cfg.max_func_len}).")

    pub_vars = 0
    consts = 0
    first_const = 1
    for i, l in enumerate(lines, 1):
        m = RE_VAR.match(l)
        if m and not m.group(1).startswith("_"):
            pub_vars += 1
        if RE_CONST.match(l):
            if consts == 0:
                first_const = i
            consts += 1
    if pub_vars > cfg.max_public_vars:
        rep.add("too-many-vars", 1, "WARN", f"{pub_vars} public vars (budget {cfg.max_public_vars}). State should live with the scene that owns it.")
    if consts > cfg.max_consts:
        rep.add("too-many-consts", first_const, "WARN", f"{consts} consts (budget {cfg.max_consts}). Tuning values belong in a Resource or @export.")

    new_count = 0
    first_new = 1
    add_child = 0
    state_matches = 0
    first_state = 1
    for i, l in enumerate(lines, 1):
        s = l.strip()
        code = l.split("#", 1)[0] if not s.startswith("#") else ""
        if code:
            if RE_PARENT.search(code):
                rep.add("no-parent-reach", i, "ERROR", "get_parent() couples this scene to its container. Emit a signal or take a typed @export.")
            if RE_UP_PATH.search(code):
                rep.add("no-parent-reach", i, "ERROR", "Path reaches outside the subtree ('../' or '/root'). Use a signal or typed @export.")
            if RE_TREE.search(code):
                rep.add("no-tree-reach", i, "ERROR", "get_tree().root/current_scene reaches the whole tree. Inject the dependency.")
            if RE_GROUP.search(code):
                rep.add("group-lookup", i, "WARN", "Group lookup as a dependency mechanism. Prefer an @export or signal.")
            if RE_RAW_KEY.search(code):
                rep.add("use-input-map", i, "WARN", "Raw key access. Use InputMap actions (Input.is_action_pressed / event.is_action_pressed).")
            if RE_CLI.search(code):
                rep.add("cli-in-game-script", i, "WARN", "Command-line handling in a game script. Put it in a dev-only tool scene.")
            if RE_PRELOAD_GD.search(code):
                rep.add("preload-script", i, "WARN", "preload() of a script path. Use class_name and run the project import.")
            if RE_NEW_NODE.search(code):
                if new_count == 0:
                    first_new = i
                new_count += len(RE_NEW_NODE.findall(code))
            if re.search(r"\badd_child\(", code):
                add_child += 1
        if RE_TEST_COMMENT.match(l):
            rep.add("test-hook", i, "WARN", "Comment mentions tests. Production scripts should not carry test hooks; drive real inputs/signals instead.")
        if RE_STATE_MATCH.match(l):
            if state_matches == 0:
                first_state = i
            state_matches += 1
        m = RE_SIGNAL.match(l)
        if m and m.group(2):
            for p in [x.strip() for x in m.group(2).split(",") if x.strip()]:
                if ":" not in p:
                    rep.add("signal-untyped", i, "WARN", f"signal '{m.group(1)}' has untyped parameter '{p}'.")
                elif re.search(r":\s*(?:Dictionary|Array)\b(?!\[)", p):
                    rep.add("signal-untyped", i, "WARN", f"signal '{m.group(1)}' passes a bare Dictionary/Array. Use a typed Resource payload.")

    if new_count > cfg.max_new_error:
        rep.add("nodes-built-in-code", first_new, "ERROR", f"{new_count} nodes built with .new() (limit {cfg.max_new_error}). Make them a .tscn scene.")
    elif new_count > cfg.max_new_warn:
        rep.add("nodes-built-in-code", first_new, "WARN", f"{new_count} nodes built with .new() (budget {cfg.max_new_warn}). Prefer a .tscn scene.")
    if add_child > cfg.max_add_child:
        rep.add("add-child-heavy", 1, "WARN", f"{add_child} add_child() calls. Static structure belongs in a scene file.")
    if state_matches >= 2:
        rep.add("inline-state-machine", first_state, "WARN", f"{state_matches} 'match phase/state/mode' blocks. Use state nodes (one child per state).")

    return rep.capped(cfg.report_cap), n


def parse_tscn(path: Path):
    ext: dict[str, str] = {}
    nodes: list[dict] = []
    cur = None
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        s = raw.strip()
        if s.startswith("[ext_resource"):
            mid = re.search(r'\bid="?([^"\s\]]+)"?', s)
            mp = re.search(r'\bpath="([^"]+)"', s)
            if mid and mp:
                ext[mid.group(1)] = mp.group(1)
        elif s.startswith("[node"):
            cur = {
                "name": (re.search(r'\bname="([^"]+)"', s) or [None, "?"])[1],
                "root": 'parent="' not in s,
                "instance": "instance=ExtResource" in s,
                "script": None,
            }
            nodes.append(cur)
        elif s.startswith("["):
            cur = None
        elif cur is not None:
            m = re.match(r'script\s*=\s*ExtResource\(\s*"?([^")\s]+)"?\s*\)', s)
            if m:
                cur["script"] = m.group(1)
    return ext, nodes


def lint_tscn(path: Path, rel: str, root: Path, gd_lines: dict[str, int], cfg: Config) -> list[Finding]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    rep = FileReport(path, rel, lines)
    ext, nodes = parse_tscn(path)
    n_nodes = len(nodes)
    n_inst = sum(1 for n in nodes if n["instance"])

    if n_nodes > cfg.max_nodes_error:
        rep.add("scene-too-big", 1, "ERROR", f"{n_nodes} nodes in one scene (limit {cfg.max_nodes_error}). Split into sub-scenes.")
    elif n_nodes > cfg.max_nodes_warn:
        rep.add("scene-too-big", 1, "WARN", f"{n_nodes} nodes in one scene (budget {cfg.max_nodes_warn}). Consider sub-scenes.")

    def script_len(node: dict) -> int | None:
        sid = node.get("script")
        if not sid or sid not in ext:
            return None
        p = ext[sid]
        return gd_lines.get(p)

    for node in nodes:
        sl = script_len(node)
        if sl is None:
            continue
        if node["root"] and n_inst >= 3 and sl > cfg.composer_script_lines:
            rep.add("composer-doing-work", 1, "WARN", f"Composer '{node['name']}' instances {n_inst} scenes but its script is {sl} lines (budget {cfg.composer_script_lines}). A composer wires and routes; move logic into a child scene.")
        if not node["root"] and sl > cfg.child_script_lines:
            rep.add("big-child-script", 1, "WARN", f"Child node '{node['name']}' has a {sl}-line script. Make it its own scene.")
    return rep.capped(cfg.report_cap)


def lint_project_godot(path: Path, rel: str) -> list[Finding]:
    out: list[Finding] = []
    in_auto = False
    count = 0
    line_no = 1
    for i, l in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        s = l.strip()
        if s.startswith("["):
            in_auto = s == "[autoload]"
            if in_auto:
                line_no = i
        elif in_auto and "=" in s:
            count += 1
    if count > 1:
        out.append(Finding(rel, line_no, "WARN", "autoloads", f"{count} autoloads. Default is none; each needs a one-line justification in the scene plan."))
    return out


def find_root(arg: Path) -> Path:
    if (arg / "project.godot").exists():
        return arg
    hits = sorted(arg.rglob("project.godot"))
    return hits[0].parent if hits else arg


def walk(root: Path, suffix: str):
    for p in sorted(root.rglob(f"*{suffix}")):
        if any(part in SKIP_DIRS for part in p.relative_to(root).parts):
            continue
        yield p


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("project", nargs="?", default=".", help="project dir (default: .)")
    ap.add_argument("--strict", action="store_true", help="treat warnings as errors")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--max-lines", type=int, default=100, help="script code-line budget (default 100; error at 2x)")
    args = ap.parse_args()

    root = find_root(Path(args.project).resolve())
    cfg = Config(args)
    findings: list[Finding] = []
    gd_lines: dict[str, int] = {}
    sizes: list[tuple[int, str]] = []

    for p in walk(root, ".gd"):
        rel = p.relative_to(root).as_posix()
        fs, n = lint_gd(p, rel, cfg)
        findings.extend(fs)
        gd_lines["res://" + rel] = n
        sizes.append((n, rel))
    scene_count = 0
    for p in walk(root, ".tscn"):
        scene_count += 1
        findings.extend(lint_tscn(p, p.relative_to(root).as_posix(), root, gd_lines, cfg))
    pg = root / "project.godot"
    if pg.exists():
        findings.extend(lint_project_godot(pg, "project.godot"))

    errors = [f for f in findings if f.level == "ERROR"]
    warns = [f for f in findings if f.level == "WARN"]
    failed = bool(errors) or (args.strict and bool(warns))

    if args.json:
        print(json.dumps({"errors": len(errors), "warnings": len(warns), "scenes": scene_count,
                          "scripts": len(sizes), "findings": [asdict(f) for f in findings]}, indent=2))
        return 1 if failed else 0

    for f in sorted(findings, key=lambda f: (f.level != "ERROR", f.path, f.line)):
        print(f"{f.path}:{f.line}: {f.level} [{f.rule}] {f.message}")
    print()
    print(f"scenes: {scene_count}   scripts: {len(sizes)}   errors: {len(errors)}   warnings: {len(warns)}")
    top = sorted(sizes, reverse=True)[:5]
    if top:
        print("longest scripts (code lines): " + ", ".join(f"{rel} {n}" for n, rel in top))
    if scene_count == 0 and sizes:
        print("note: no .tscn files found; a project with scripts and no scenes is not using composition.")
    print("RESULT: " + ("FAIL" if failed else "ok"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
