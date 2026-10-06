#!/usr/bin/env python3
"""
Slide Coherence Linter for Reveal.js Presentations.

Strictly verifies structural parity, styling alignment, and code synchronization
between two localized Reveal.js Markdown slide decks (e.g. slides-en.md and slides-it.md).

Core Rules Enforced:
1. Slide Count Parity: Both decks must have the exact same number of slides.
2. Agenda Parity: Both decks must have an Agenda slide with the exact same number of items.
3. Style Elements & HTML Parity: All HTML tags, CSS classes, inline styles, and Reveal.js
   directives (<!-- .slide: ... -->, <!-- .element: ... -->) must match exactly.
4. Code Content Parity: All code blocks must be identical in content and language (untranslated).
5. Image Parity: All image sources (Markdown and HTML) must match identically across decks.

Safety Guarantee:
- 100% Read-Only: Never modifies any files on disk.
- Zero External Dependencies: Pure Python 3 standard library.
- Exit code 1 on errors, 0 on 100% coherence.
"""

import argparse
from dataclasses import dataclass, field
import difflib
import html
import os
from pathlib import Path
import re
import sys
from typing import Dict, List, Optional, Set, Tuple


# Terminal ANSI Colors
class Colors:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    CYAN = "\033[36m"
    GRAY = "\033[90m"


def colorize(text: str, color_code: str, use_color: bool = True) -> str:
    """Format text with ANSI color code if enabled."""
    if not use_color:
        return text
    return f"{color_code}{text}{Colors.RESET}"


@dataclass
class HtmlTagInfo:
    """Represents an HTML tag or Reveal.js directive for style comparison."""
    tag_type: str  # tag name or 'directive'
    full_text: str
    classes: List[str] = field(default_factory=list)
    style: str = ""
    is_closing: bool = False
    line_number: Optional[int] = None
    line_text: str = ""


@dataclass
class LineToken:
    """Represents a structural markup token on a single line."""
    kind: str  # "directive", "tag", "code"
    text: str
    position: int
    tag_name: str = ""
    classes: List[str] = field(default_factory=list)
    style: str = ""
    is_closing: bool = False


@dataclass
class SlideData:
    """Structured representation of an individual slide."""
    index: int
    raw_content: str
    body: str
    notes: Optional[str]
    headings: List[Tuple[int, str]] = field(default_factory=list)  # (level, text)
    code_blocks: List[Tuple[str, str]] = field(default_factory=list)  # (language, code)
    table_dimensions: List[Tuple[int, int]] = field(default_factory=list)  # (columns, rows)
    style_elements: List[HtmlTagInfo] = field(default_factory=list)
    fragment_count: int = 0
    agenda_items: List[str] = field(default_factory=list)
    links: List[str] = field(default_factory=list)
    images: List[str] = field(default_factory=list)
    unordered_list_count: int = 0
    ordered_list_count: int = 0
    start_line: int = 1
    body_lines: List[Tuple[int, str]] = field(default_factory=list)  # (file_line_num, line_text)
    separator: str = "---"

    @property
    def primary_title(self) -> str:
        """Return the highest-level or first heading, or fallback description."""
        if self.headings:
            sorted_headings = sorted(self.headings, key=lambda h: h[0])
            return html.unescape(sorted_headings[0][1])
        return "(Untitled Slide)"

    @property
    def is_agenda(self) -> bool:
        """Check if this slide is the Agenda slide."""
        for _, text in self.headings:
            if "agenda" in text.lower():
                return True
        return False


@dataclass
class Issue:
    """Represents a discovered linting defect or warning."""
    slide_index: Optional[int]
    category: str
    severity: str  # "ERROR" or "WARNING"
    message: str
    line_number: Optional[int] = None


def extract_line_tokens(line: str) -> List[LineToken]:
    """Extract structural tokens (directives, HTML tags, inline code) on a single line with their positions."""
    tokens = []
    # Match directives: <!-- .element: ... --> or <!-- .slide: ... -->
    for m in re.finditer(r"<!--\s*\.(slide|element):\s*(.*?)\s*-->", line):
        kind, content = m.groups()
        tokens.append(
            LineToken(
                kind="directive",
                text=m.group(0),
                position=m.start(),
                tag_name=f"directive-{kind}",
                style=content.strip(),
            )
        )

    # Match HTML tags: <...>
    for m in re.finditer(r"<(/?[a-zA-Z0-9_-]+)(.*?)>", line):
        full = m.group(0)
        raw_tag = m.group(1)
        attrs = m.group(2)
        is_closing = raw_tag.startswith("/")
        tag_name = raw_tag.lstrip("/").lower()

        class_match = re.search(r'class=["\']([^"\']+)["\']', attrs)
        classes = sorted(class_match.group(1).split()) if class_match else []

        style_match = re.search(r'style=["\']([^"\']+)["\']', attrs)
        style_val = style_match.group(1).strip() if style_match else ""

        tokens.append(
            LineToken(
                kind="tag",
                text=full,
                position=m.start(),
                tag_name=tag_name,
                classes=classes,
                style=style_val,
                is_closing=is_closing,
            )
        )

    # Match inline code: `...`
    for m in re.finditer(r"`([^`]+)`", line):
        tokens.append(
            LineToken(
                kind="code",
                text=m.group(0),
                position=m.start(),
                tag_name="code-span",
                style=m.group(1).strip(),
            )
        )

    tokens.sort(key=lambda t: t.position)
    return tokens


def extract_style_elements(body_no_code: str, body_start_line: int = 1) -> List[HtmlTagInfo]:
    """
    Extract all HTML tags, inline styles, CSS classes, and Reveal.js directives.
    Used to enforce that all style elements and HTML code are identical across decks.
    """
    elements = []
    lines = body_no_code.splitlines()

    # Tokenize HTML tags and Reveal comments line by line
    token_pattern = re.compile(r"(<!--\s*\.(?:slide|element):\s*.*?-->|<[^>]+>)")
    for rel_idx, line in enumerate(lines):
        line_num = body_start_line + rel_idx
        for match in token_pattern.finditer(line):
            token = match.group(1).strip()

            # Reveal directives: <!-- .slide: ... --> or <!-- .element: ... -->
            directive_match = re.match(r"^<!--\s*\.(slide|element):\s*(.*?)\s*-->$", token)
            if directive_match:
                kind, content = directive_match.groups()
                elements.append(
                    HtmlTagInfo(
                        tag_type=f"directive-{kind}",
                        full_text=token,
                        style=content.strip(),
                        line_number=line_num,
                        line_text=line.strip(),
                    )
                )
                continue

            # HTML closing tag </tag>
            closing_match = re.match(r"^</([a-zA-Z0-9_-]+)>$", token)
            if closing_match:
                elements.append(
                    HtmlTagInfo(
                        tag_type=closing_match.group(1).lower(),
                        full_text=token,
                        is_closing=True,
                        line_number=line_num,
                        line_text=line.strip(),
                    )
                )
                continue

            # HTML opening or self-closing tag <tag ...>
            opening_match = re.match(r"^<([a-zA-Z0-9_-]+)(.*?)>$", token, flags=re.DOTALL)
            if opening_match:
                tag_name = opening_match.group(1).lower()
                attrs_str = opening_match.group(2)

                # Extract class="..."
                class_match = re.search(r'class=["\']([^"\']+)["\']', attrs_str)
                classes = sorted(class_match.group(1).split()) if class_match else []

                # Extract style="..."
                style_match = re.search(r'style=["\']([^"\']+)["\']', attrs_str)
                style_val = style_match.group(1).strip() if style_match else ""

                elements.append(
                    HtmlTagInfo(
                        tag_type=tag_name,
                        full_text=token,
                        classes=classes,
                        style=style_val,
                        line_number=line_num,
                        line_text=line.strip(),
                    )
                )

    return elements


def parse_slide(raw_slide: str, index: int, start_line: int = 1) -> SlideData:
    """Parse a single slide section into structured components."""
    # Reveal.js speaker note separator is ^Note:
    note_match = re.search(r"^Note:\s*", raw_slide, flags=re.MULTILINE)
    if note_match:
        body = raw_slide[:note_match.start()].rstrip()
        notes = raw_slide[note_match.end():].strip()
    else:
        body = raw_slide.rstrip()
        notes = None

    body_lines = [(start_line + i, l) for i, l in enumerate(body.splitlines())]

    # Mask code blocks with blank lines so line numbers and offsets match 1:1
    def mask_code_block(match: re.Match) -> str:
        return "\n" * match.group(0).count("\n")

    body_no_code = re.sub(r"```.*?```", mask_code_block, body, flags=re.DOTALL)

    # Headings: # through ######
    heading_matches = re.findall(r"^(#{1,6})\s+(.+)$", body_no_code, flags=re.MULTILINE)
    headings = [(len(h[0]), h[1].strip()) for h in heading_matches]

    # Code blocks: ```lang\ncode\n```
    code_matches = re.findall(r"```([a-zA-Z0-9_-]*)\n(.*?)```", body, flags=re.DOTALL)
    code_blocks = [(lang.strip(), code.strip()) for lang, code in code_matches]

    # Tables: find markdown table blocks
    table_dimensions = []
    table_lines = [line.strip() for line in body_no_code.splitlines() if line.strip().startswith("|")]
    if table_lines:
        current_table = []
        for line in table_lines:
            cells = [c.strip() for c in line.split("|")[1:-1]]
            if cells:
                current_table.append(cells)
            else:
                if len(current_table) >= 2:
                    cols = len(current_table[0])
                    rows = max(0, len(current_table) - 2)
                    table_dimensions.append((cols, rows))
                current_table = []
        if len(current_table) >= 2:
            cols = len(current_table[0])
            rows = max(0, len(current_table) - 2)
            table_dimensions.append((cols, rows))

    # Style elements (HTML code, classes, inline styles, directives)
    style_elements = extract_style_elements(body_no_code, body_start_line=start_line)

    # Fragments count
    frag_count = len(re.findall(r'class="[^"]*\bfragment\b[^"]*"', body_no_code))

    # Agenda items (numbered list items if Agenda)
    is_agenda = any("agenda" in text.lower() for _, text in headings)
    agenda_items = []
    if is_agenda:
        agenda_items = re.findall(r"^\s*\d+\.\s+(.+)$", body_no_code, flags=re.MULTILINE)

    # Links: [text](url) and <a href="url">
    md_links = re.findall(r'\[(?:[^\]]*)\]\(([^)]+)\)', body_no_code)
    html_links = re.findall(r'href=["\']([^"\']+)["\']', body_no_code)
    links = sorted(list(set(md_links + html_links)))

    # Images: ![alt](src) and <img src="..."> in order of appearance
    img_matches = []
    for m in re.finditer(r'!\[(?:[^\]]*)\]\(([^)\s]+)(?:\s+["\'][^"\']*["\'])?\)', body_no_code):
        img_matches.append((m.start(), m.group(1).strip()))
    for m in re.finditer(r'<img\b[^>]*?\bsrc=["\']([^"\']+)["\']', body_no_code, flags=re.IGNORECASE | re.DOTALL):
        img_matches.append((m.start(), m.group(1).strip()))
    img_matches.sort(key=lambda x: x[0])
    images = [img for _, img in img_matches]

    # Lists
    ul_count = len(re.findall(r"^\s*[\*\-]\s+", body_no_code, flags=re.MULTILINE))
    ol_count = len(re.findall(r"^\s*\d+\.\s+", body_no_code, flags=re.MULTILINE))

    return SlideData(
        index=index,
        raw_content=raw_slide,
        body=body,
        notes=notes,
        headings=headings,
        code_blocks=code_blocks,
        table_dimensions=table_dimensions,
        style_elements=style_elements,
        fragment_count=frag_count,
        agenda_items=agenda_items,
        links=links,
        images=images,
        unordered_list_count=ul_count,
        ordered_list_count=ol_count,
        start_line=start_line,
        body_lines=body_lines,
    )


def load_presentation(file_path: Path) -> List[SlideData]:
    """Read a presentation markdown file and parse each slide safely (Read-Only)."""
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.splitlines()
    slides_data: List[Tuple[int, List[str], str]] = []  # (start_line, lines, separator)
    current_lines: List[str] = []
    current_start = 1
    current_sep = "---"

    for idx, line in enumerate(lines, 1):
        m = re.match(r"^\s*(---|--)\s*$", line)
        if m:
            slides_data.append((current_start, current_lines, current_sep))
            current_lines = []
            current_start = idx + 1
            current_sep = m.group(1)
        else:
            current_lines.append(line)
    slides_data.append((current_start, current_lines, current_sep))

    # Drop leading empty slide if any
    if slides_data and not any(l.strip() for l in slides_data[0][1]):
        slides_data = slides_data[1:]

    slides = []
    for idx, (start_line, s_lines, sep) in enumerate(slides_data, 1):
        raw = "\n".join(s_lines)
        slide_obj = parse_slide(raw, idx, start_line=start_line)
        slide_obj.separator = sep
        slides.append(slide_obj)
    return slides


class SlideDeckLinter:
    """Enforces strict coherence between two localized SlideData deck representations."""

    def __init__(self, en_slides: List[SlideData], it_slides: List[SlideData], strict: bool = False):
        self.en_slides = en_slides
        self.it_slides = it_slides
        self.strict = strict
        self.issues: List[Issue] = []

    # =========================================================================
    # Rule 1: Both decks have to have the same number of slides and separators
    # =========================================================================
    def check_slide_count(self) -> None:
        """Rule 1: Verify identical slide counts across both decks."""
        len_en = len(self.en_slides)
        len_it = len(self.it_slides)
        if len_en != len_it:
            self.issues.append(
                Issue(
                    slide_index=None,
                    category="slides",
                    severity="ERROR",
                    message=f"Total slide count mismatch: primary deck has {len_en} slides, secondary deck has {len_it} slides.",
                )
            )

    def check_separators(self, s_en: SlideData, s_it: SlideData) -> None:
        """Verify identical Reveal.js separator (--- vs --) across decks."""
        if s_en.separator != s_it.separator:
            self.issues.append(
                Issue(
                    slide_index=s_en.index,
                    category="slides",
                    severity="ERROR",
                    line_number=s_en.start_line,
                    message=(
                        f"Slide separator mismatch: primary uses '{s_en.separator}', "
                        f"secondary uses '{s_it.separator}'."
                    ),
                )
            )

    # =========================================================================
    # Rule 2: Both have to have agenda with same number of elements
    # =========================================================================
    def check_agenda(self) -> None:
        """Rule 2: Verify both decks have an Agenda slide and identical agenda items count."""
        agenda_en = [(s.index, s) for s in self.en_slides if s.is_agenda]
        agenda_it = [(s.index, s) for s in self.it_slides if s.is_agenda]

        if not agenda_en:
            self.issues.append(
                Issue(
                    slide_index=None,
                    category="agenda",
                    severity="ERROR",
                    message="Primary deck is missing an 'Agenda' slide.",
                )
            )
        if not agenda_it:
            self.issues.append(
                Issue(
                    slide_index=None,
                    category="agenda",
                    severity="ERROR",
                    message="Secondary deck is missing an 'Agenda' slide.",
                )
            )

        if agenda_en and agenda_it:
            idx_en, s_en = agenda_en[0]
            idx_it, s_it = agenda_it[0]

            count_en = len(s_en.agenda_items)
            count_it = len(s_it.agenda_items)

            if count_en == 0 or count_it == 0:
                self.issues.append(
                    Issue(
                        slide_index=idx_en,
                        category="agenda",
                        severity="ERROR",
                        message=f"Agenda elements could not be parsed: primary found {count_en}, secondary found {count_it}.",
                    )
                )
            elif count_en != count_it:
                self.issues.append(
                    Issue(
                        slide_index=idx_en,
                        category="agenda",
                        severity="ERROR",
                        message=(
                            f"Agenda element count mismatch: primary has {count_en} items, "
                            f"secondary has {count_it} items."
                        ),
                    )
                )

    # =========================================================================
    # Rule 3: All of the style elements as html code or classes has to be exactly the same
    # =========================================================================
    def check_line_token_order(self, s_en: SlideData, s_it: SlideData) -> Set[int]:
        """Verify that corresponding list items have identical directive, tag, and code ordering."""
        mismatched_lines: Set[int] = set()

        def get_list_items(body_lines: List[Tuple[int, str]]) -> List[Tuple[str, int, str]]:
            items = []
            for line_no, line in body_lines:
                m = re.match(r"^\s*(\d+\.|[\*\-\+])\s+", line)
                if m:
                    items.append((m.group(1), line_no, line))
            return items

        items_en = get_list_items(s_en.body_lines)
        items_it = get_list_items(s_it.body_lines)

        min_items = min(len(items_en), len(items_it))
        for i in range(min_items):
            lbl_en, lno_en, text_en = items_en[i]
            lbl_it, lno_it, text_it = items_it[i]

            toks_en = extract_line_tokens(text_en)
            toks_it = extract_line_tokens(text_it)

            seq_en = [t.tag_name for t in toks_en]
            seq_it = [t.tag_name for t in toks_it]

            if seq_en != seq_it:
                # If they contain the same tokens in different order, report order mismatch
                if sorted(seq_en) == sorted(seq_it):
                    mismatched_lines.add(lno_en)
                    repr_en = " -> ".join([t.text for t in toks_en])
                    repr_it = " -> ".join([t.text for t in toks_it])
                    self.issues.append(
                        Issue(
                            slide_index=s_en.index,
                            category="style",
                            severity="ERROR",
                            line_number=lno_en,
                            message=(
                                f"Directive/tag order mismatch on list item '{lbl_en}' (primary line {lno_en} vs secondary line {lno_it}): "
                                f"primary has [{repr_en}] vs secondary has [{repr_it}]. "
                                f"The order of Reveal.js directives relative to HTML tags and inline code must match exactly."
                            ),
                        )
                    )

        return mismatched_lines

    def check_style_elements(self, s_en: SlideData, s_it: SlideData) -> None:
        """Rule 3: Enforce exact match on HTML code, tags, CSS classes, inline styles, and directives."""
        # First check line-level token order on list items
        order_mismatched_lines = self.check_line_token_order(s_en, s_it)

        elems_en = s_en.style_elements
        elems_it = s_it.style_elements

        if len(elems_en) != len(elems_it):
            tags_en_repr = [f"<{e.tag_type}>" if not e.is_closing else f"</{e.tag_type}>" for e in elems_en]
            tags_it_repr = [f"<{e.tag_type}>" if not e.is_closing else f"</{e.tag_type}>" for e in elems_it]
            self.issues.append(
                Issue(
                    slide_index=s_en.index,
                    category="style",
                    severity="ERROR",
                    line_number=s_en.start_line,
                    message=(
                        f"Style/HTML elements count mismatch: primary has {len(elems_en)} tags/directives, "
                        f"secondary has {len(elems_it)}. Tags in primary: {tags_en_repr} vs secondary: {tags_it_repr}."
                    ),
                )
            )
            return

        for idx, (e_en, e_it) in enumerate(zip(elems_en, elems_it), 1):
            line_no = e_en.line_number or s_en.start_line

            # If this line was already reported for having its elements out of order,
            # skip reporting duplicate false tag mismatches caused by shifted indices.
            if e_en.line_number in order_mismatched_lines:
                continue

            # Check tag name and closing status
            if e_en.tag_type != e_it.tag_type or e_en.is_closing != e_it.is_closing:
                self.issues.append(
                    Issue(
                        slide_index=s_en.index,
                        category="style",
                        severity="ERROR",
                        line_number=line_no,
                        message=(
                            f"HTML tag #{idx} mismatch: primary has '{e_en.full_text}', "
                            f"secondary has '{e_it.full_text}'."
                        ),
                    )
                )
                continue

            # Check CSS classes
            if e_en.classes != e_it.classes:
                self.issues.append(
                    Issue(
                        slide_index=s_en.index,
                        category="style",
                        severity="ERROR",
                        line_number=line_no,
                        message=(
                            f"HTML element #{idx} <{e_en.tag_type}> class mismatch: "
                            f"primary classes={e_en.classes}, secondary classes={e_it.classes}."
                        ),
                    )
                )

            # Check inline styles
            if e_en.style != e_it.style:
                self.issues.append(
                    Issue(
                        slide_index=s_en.index,
                        category="style",
                        severity="ERROR",
                        line_number=line_no,
                        message=(
                            f"HTML element #{idx} <{e_en.tag_type}> style mismatch: "
                            f"primary style='{e_en.style}', secondary style='{e_it.style}'."
                        ),
                    )
                )

    # =========================================================================
    # Rule 4: All the code parts has to be the same, same content, code is not translated
    # =========================================================================
    def check_code_parity(self, s_en: SlideData, s_it: SlideData) -> None:
        """Rule 4: Verify code block count, language, and exact identical content (no translation)."""
        cb_en = s_en.code_blocks
        cb_it = s_it.code_blocks

        if len(cb_en) != len(cb_it):
            self.issues.append(
                Issue(
                    slide_index=s_en.index,
                    category="code",
                    severity="ERROR",
                    line_number=s_en.start_line,
                    message=f"Code blocks count mismatch: primary has {len(cb_en)}, secondary has {len(cb_it)}.",
                )
            )
            return

        for idx, ((lang_en, code_en), (lang_it, code_it)) in enumerate(zip(cb_en, cb_it), 1):
            if lang_en != lang_it:
                self.issues.append(
                    Issue(
                        slide_index=s_en.index,
                        category="code",
                        severity="ERROR",
                        line_number=s_en.start_line,
                        message=f"Code block #{idx} language tag mismatch: primary='{lang_en}', secondary='{lang_it}'.",
                    )
                )

            # Rule 4 explicitly states:
            # "all the code parts has to be the same, same content, code is not translated"
            clean_en = code_en.strip()
            clean_it = code_it.strip()
            if clean_en != clean_it:
                # Find first line of divergence
                lines_en = clean_en.splitlines()
                lines_it = clean_it.splitlines()
                first_diff = ""
                for l_idx, (le, li) in enumerate(zip(lines_en, lines_it), 1):
                    if le != li:
                        first_diff = f"Line {l_idx}: '{le}' != '{li}'"
                        break
                if not first_diff:
                    first_diff = f"Lines count: primary={len(lines_en)}, secondary={len(lines_it)}"

                self.issues.append(
                    Issue(
                        slide_index=s_en.index,
                        category="code",
                        severity="ERROR",
                        line_number=s_en.start_line,
                        message=f"Code block #{idx} ({lang_en}) content is not identical (translated or divergent). {first_diff}",
                    )
                )

    # =========================================================================
    # Supporting Structural Checks
    # =========================================================================
    def check_headings(self, s_en: SlideData, s_it: SlideData) -> None:
        """Verify heading levels and count per slide."""
        h_en = s_en.headings
        h_it = s_it.headings
        if len(h_en) != len(h_it):
            self.issues.append(
                Issue(
                    slide_index=s_en.index,
                    category="headings",
                    severity="ERROR",
                    line_number=s_en.start_line,
                    message=f"Heading count mismatch: primary has {len(h_en)}, secondary has {len(h_it)}.",
                )
            )
            return

        for idx, ((lvl_en, title_en), (lvl_it, title_it)) in enumerate(zip(h_en, h_it), 1):
            if lvl_en != lvl_it:
                self.issues.append(
                    Issue(
                        slide_index=s_en.index,
                        category="headings",
                        severity="ERROR",
                        line_number=s_en.start_line,
                        message=(
                            f"Heading #{idx} level mismatch: primary is H{lvl_en} ('{title_en}'), "
                            f"secondary is H{lvl_it} ('{title_it}')."
                        ),
                    )
                )

    def check_fragments(self, s_en: SlideData, s_it: SlideData) -> None:
        """Verify fragment animation count and check for fragment attachment bugs."""
        if s_en.fragment_count != s_it.fragment_count:
            self.issues.append(
                Issue(
                    slide_index=s_en.index,
                    category="fragments",
                    severity="ERROR",
                    line_number=s_en.start_line,
                    message=(
                        f"Fragment animation count mismatch: primary has {s_en.fragment_count} fragments, "
                        f"secondary has {s_it.fragment_count} fragments."
                    ),
                )
            )

        # Check for Reveal.js Markdown inline fragment bugs across all lines in both decks
        for deck_name, slide in [("primary", s_en), ("secondary", s_it)]:
            for line_no, line in slide.body_lines:
                frag_match = re.search(r"<!--\s*\.element:\s*class=[\"'](?:[^\"']*\b)?fragment\b.*?-->", line)
                if not frag_match:
                    continue

                # 1. Trailing after <br> in a list item
                is_list_item = bool(re.match(r"^\s*(?:\d+\.|\*|\-|\+)\s+", line))
                br_match = re.search(r"<br\s*/?>", line)
                if is_list_item and br_match and frag_match.start() > br_match.start():
                    self.issues.append(
                        Issue(
                            slide_index=slide.index,
                            category="style",
                            severity="ERROR",
                            line_number=line_no,
                            message=(
                                f"Reveal.js fragment attachment defect in {deck_name} deck (line {line_no}): "
                                f"'{frag_match.group(0)}' is placed after '<br>'. "
                                f"In Reveal.js, this attaches to inline content after <br> rather than the list item, "
                                f"causing the bullet/item to be visible immediately before the fragment triggers. "
                                f"Place it before '<br>' (e.g. '... {frag_match.group(0)} <br>...')."
                            ),
                        )
                    )
                    continue

                # 2. Immediately follows an inline closing tag
                tag_follow = re.search(
                    r"</(small|code|span|strong|em|a|b|i)>\s*(<!--\s*\.element:\s*class=[\"'](?:[^\"']*\b)?fragment\b.*?-->)",
                    line,
                )
                if tag_follow:
                    self.issues.append(
                        Issue(
                            slide_index=slide.index,
                            category="style",
                            severity="ERROR",
                            line_number=line_no,
                            message=(
                                f"Reveal.js fragment attachment defect in {deck_name} deck (line {line_no}): "
                                f"'{tag_follow.group(2)}' immediately follows '</{tag_follow.group(1)}>'. "
                                f"In Reveal.js, this attaches to the inline child rather than the list item, "
                                f"causing the bullet/item to be visible immediately before the fragment triggers. "
                                f"Place '{tag_follow.group(2)}' before '<br>' or before the inline tag."
                            ),
                        )
                    )
                    continue

                # 3. Immediately follows inline code `...`
                code_follow = re.search(
                    r"(`[^`]+`)\s*(<!--\s*\.element:\s*class=[\"'](?:[^\"']*\b)?fragment\b.*?-->)",
                    line,
                )
                if code_follow:
                    self.issues.append(
                        Issue(
                            slide_index=slide.index,
                            category="style",
                            severity="ERROR",
                            line_number=line_no,
                            message=(
                                f"Reveal.js fragment attachment defect in {deck_name} deck (line {line_no}): "
                                f"'{code_follow.group(2)}' immediately follows inline code {code_follow.group(1)}. "
                                f"In Reveal.js, this attaches to the inline code rather than the list item, "
                                f"causing the bullet/item to be visible immediately before the fragment triggers. "
                                f"Place '{code_follow.group(2)}' before the code (e.g. '... {code_follow.group(2)} {code_follow.group(1)}')."
                            ),
                        )
                    )
                    continue

                # 4. Immediately follows inline bold/italic
                bold_follow = re.search(
                    r"(\*\*[^*]+\*\*|__[^\_]+__)\s*(<!--\s*\.element:\s*class=[\"'](?:[^\"']*\b)?fragment\b.*?-->)",
                    line,
                )
                if bold_follow:
                    self.issues.append(
                        Issue(
                            slide_index=slide.index,
                            category="style",
                            severity="ERROR",
                            line_number=line_no,
                            message=(
                                f"Reveal.js fragment attachment defect in {deck_name} deck (line {line_no}): "
                                f"'{bold_follow.group(2)}' immediately follows bold formatting {bold_follow.group(1)}. "
                                f"In Reveal.js, this attaches to <strong> rather than the list item."
                            ),
                        )
                    )
                    continue

                # 5. Followed on the same line by Markdown bold/italic formatting
                bold_after = re.search(
                    r"(<!--\s*\.element:[^>]*-->).*?(\*\*[^*]+\*\*|__[^\_]+__)",
                    line,
                )
                if bold_after:
                    self.issues.append(
                        Issue(
                            slide_index=slide.index,
                            category="style",
                            severity="ERROR",
                            line_number=line_no,
                            message=(
                                f"Reveal.js Markdown formatting defect in {deck_name} deck (line {line_no}): "
                                f"'{bold_after.group(1)}' is followed by Markdown bold formatting {bold_after.group(2)}. "
                                f"Markdown bold syntax does not parse correctly when preceded by Reveal.js directives in list items; "
                                f"use plain text instead."
                            ),
                        )
                    )
                    continue
    def check_tables(self, s_en: SlideData, s_it: SlideData) -> None:
        """Verify markdown tables presence and dimensions."""
        t_en = s_en.table_dimensions
        t_it = s_it.table_dimensions

        if len(t_en) != len(t_it):
            self.issues.append(
                Issue(
                    slide_index=s_en.index,
                    category="tables",
                    severity="ERROR",
                    line_number=s_en.start_line,
                    message=f"Table count mismatch: primary has {len(t_en)}, secondary has {len(t_it)}.",
                )
            )
            return

        for idx, (dim_en, dim_it) in enumerate(zip(t_en, t_it), 1):
            if dim_en != dim_it:
                self.issues.append(
                    Issue(
                        slide_index=s_en.index,
                        category="tables",
                        severity="ERROR",
                        line_number=s_en.start_line,
                        message=(
                            f"Table #{idx} dimension mismatch: "
                            f"primary is {dim_en[0]} cols x {dim_en[1]} rows, "
                            f"secondary is {dim_it[0]} cols x {dim_it[1]} rows."
                        ),
                    )
                )

    def check_speaker_notes(self, s_en: SlideData, s_it: SlideData) -> None:
        """Verify speaker notes presence parity."""
        has_en = s_en.notes is not None and len(s_en.notes.strip()) > 0
        has_it = s_it.notes is not None and len(s_it.notes.strip()) > 0

        if has_en != has_it:
            sev = "ERROR" if self.strict else "WARNING"
            present = "primary" if has_en else "secondary"
            missing = "secondary" if has_en else "primary"
            self.issues.append(
                Issue(
                    slide_index=s_en.index,
                    category="notes",
                    severity=sev,
                    line_number=s_en.start_line,
                    message=f"Speaker notes presence mismatch: present in {present}, missing in {missing}.",
                )
            )

    # =========================================================================
    # Rule 5: Used images must match identically between decks
    # =========================================================================
    def check_images(self, s_en: SlideData, s_it: SlideData) -> None:
        """Rule 5: Verify image count and image sources match identically between decks."""
        imgs_en = s_en.images
        imgs_it = s_it.images

        if len(imgs_en) != len(imgs_it):
            self.issues.append(
                Issue(
                    slide_index=s_en.index,
                    category="images",
                    severity="ERROR",
                    line_number=s_en.start_line,
                    message=(
                        f"Image count mismatch: primary has {len(imgs_en)} image(s) {imgs_en}, "
                        f"secondary has {len(imgs_it)} image(s) {imgs_it}."
                    ),
                )
            )
            return

        for idx, (img_en, img_it) in enumerate(zip(imgs_en, imgs_it), 1):
            if img_en != img_it:
                self.issues.append(
                    Issue(
                        slide_index=s_en.index,
                        category="images",
                        severity="ERROR",
                        line_number=s_en.start_line,
                        message=(
                            f"Image #{idx} source mismatch: "
                            f"primary has '{img_en}', secondary has '{img_it}'."
                        ),
                    )
                )

    def run_all(self, enabled_categories: Optional[List[str]] = None) -> List[Issue]:
        """Execute all validation rules across slide decks."""
        self.issues.clear()
        categories = enabled_categories or [
            "slides", "agenda", "style", "code", "headings", "fragments", "tables", "notes", "images"
        ]

        # Deck-level checks
        if "slides" in categories:
            self.check_slide_count()
        if "agenda" in categories:
            self.check_agenda()

        # Per-slide checks
        min_len = min(len(self.en_slides), len(self.it_slides))
        for i in range(min_len):
            s_en = self.en_slides[i]
            s_it = self.it_slides[i]

            if "slides" in categories:
                self.check_separators(s_en, s_it)
            if "style" in categories:
                self.check_style_elements(s_en, s_it)
            if "code" in categories:
                self.check_code_parity(s_en, s_it)
            if "headings" in categories:
                self.check_headings(s_en, s_it)
            if "fragments" in categories or "style" in categories:
                self.check_fragments(s_en, s_it)
            if "tables" in categories:
                self.check_tables(s_en, s_it)
            if "notes" in categories:
                self.check_speaker_notes(s_en, s_it)
            if "images" in categories:
                self.check_images(s_en, s_it)

        return self.issues


def print_report(
    issues: List[Issue],
    en_slides: List[SlideData],
    it_slides: List[SlideData],
    verbose: bool,
    use_color: bool
) -> int:
    """Print a clean, formatted report of lint results and return exit status code."""
    errors = [i for i in issues if i.severity == "ERROR"]
    warnings = [i for i in issues if i.severity == "WARNING"]

    total_slides = max(len(en_slides), len(it_slides))

    header = f"Slide Coherence Linter: {len(en_slides)} primary slides vs {len(it_slides)} secondary slides"
    print(colorize("=" * len(header), Colors.BOLD, use_color))
    print(colorize(header, Colors.BOLD, use_color))
    print(colorize("=" * len(header), Colors.BOLD, use_color))

    # Slide by slide overview
    slide_issues: Dict[Optional[int], List[Issue]] = {}
    for issue in issues:
        slide_issues.setdefault(issue.slide_index, []).append(issue)

    for idx in range(1, total_slides + 1):
        s_en = en_slides[idx - 1] if idx <= len(en_slides) else None
        s_it = it_slides[idx - 1] if idx <= len(it_slides) else None

        title_en = s_en.primary_title if s_en else "(No slide)"
        title_it = s_it.primary_title if s_it else "(No slide)"

        curr_issues = slide_issues.get(idx, [])
        curr_errors = [i for i in curr_issues if i.severity == "ERROR"]
        curr_warnings = [i for i in curr_issues if i.severity == "WARNING"]

        if curr_errors:
            status_tag = colorize("[FAIL]", Colors.RED + Colors.BOLD, use_color)
        elif curr_warnings:
            status_tag = colorize("[WARN]", Colors.YELLOW + Colors.BOLD, use_color)
        else:
            status_tag = colorize("[PASS]", Colors.GREEN, use_color)

        if curr_issues or verbose:
            print(f"Slide {idx:02d} {status_tag} {colorize(title_en, Colors.CYAN, use_color)} / {colorize(title_it, Colors.GRAY, use_color)}")
            for issue in curr_issues:
                line_info = f" (line {issue.line_number})" if issue.line_number is not None else ""
                prefix = colorize(f"  • {issue.severity} [{issue.category}]{line_info}:", Colors.RED if issue.severity == "ERROR" else Colors.YELLOW, use_color)
                print(f"{prefix} {issue.message}")

    # Deck Level issues (not tied to a specific slide)
    general_issues = slide_issues.get(None, [])
    if general_issues:
        print(colorize("\nDeck Level Issues:", Colors.BOLD, use_color))
        for issue in general_issues:
            line_info = f" (line {issue.line_number})" if issue.line_number is not None else ""
            prefix = colorize(f"  • {issue.severity} [{issue.category}]{line_info}:", Colors.RED if issue.severity == "ERROR" else Colors.YELLOW, use_color)
            print(f"{prefix} {issue.message}")

    # Final summary box
    print("\n" + colorize("-" * 50, Colors.GRAY, use_color))
    summary_line = f"Summary: {len(errors)} error(s), {len(warnings)} warning(s) across {total_slides} slide pairs."
    if errors:
        print(colorize(f"RESULT: FAILED ({summary_line})", Colors.RED + Colors.BOLD, use_color))
        return 1
    elif warnings:
        print(colorize(f"RESULT: PASSED with warnings ({summary_line})", Colors.YELLOW + Colors.BOLD, use_color))
        return 0
    else:
        print(colorize(f"RESULT: PASSED (100% coherent across all {total_slides} slides)", Colors.GREEN + Colors.BOLD, use_color))
        return 0


def main() -> None:
    """CLI entrypoint."""
    script_dir = Path(__file__).resolve().parent

    default_en = script_dir / "slides-en.md"
    default_it = script_dir / "slides-it.md"

    # If run from repo root or other location, locate slides
    if not default_en.exists():
        repo_slides_en = Path("docs/pages/slides/slides-en.md")
        if repo_slides_en.exists():
            default_en = repo_slides_en
            default_it = Path("docs/pages/slides/slides-it.md")

    parser = argparse.ArgumentParser(
        description="Verify strict structural coherence, styling, and code parity between localized Reveal.js slide decks."
    )
    parser.add_argument("file1", nargs="?", default=str(default_en), help="Path to primary slide deck (default: slides-en.md)")
    parser.add_argument("file2", nargs="?", default=str(default_it), help="Path to secondary slide deck (default: slides-it.md)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Display all slides, including passing ones")
    parser.add_argument("-s", "--strict", action="store_true", help="Elevate all warnings to errors (fail on warnings)")
    parser.add_argument("--no-color", action="store_true", help="Disable colored terminal output")
    parser.add_argument(
        "--rules",
        type=str,
        default="",
        help="Comma-separated list of rules to check (e.g. 'slides,agenda,style,code,headings,fragments,tables,notes,images')",
    )

    args = parser.parse_args()

    en_path = Path(args.file1)
    it_path = Path(args.file2)

    if not en_path.exists():
        print(f"Error: Primary slide file not found: {en_path}", file=sys.stderr)
        sys.exit(2)
    if not it_path.exists():
        print(f"Error: Secondary slide file not found: {it_path}", file=sys.stderr)
        sys.exit(2)

    use_color = not args.no_color and sys.stdout.isatty()

    try:
        en_slides = load_presentation(en_path)
        it_slides = load_presentation(it_path)
    except Exception as e:
        print(f"Error loading slide files: {e}", file=sys.stderr)
        sys.exit(2)

    rules = [r.strip() for r in args.rules.split(",") if r.strip()] if args.rules else None

    linter = SlideDeckLinter(en_slides, it_slides, strict=args.strict)
    issues = linter.run_all(enabled_categories=rules)

    exit_code = print_report(issues, en_slides, it_slides, verbose=args.verbose, use_color=use_color)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
