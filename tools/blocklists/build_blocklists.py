#!/usr/bin/env python3
"""Builds Zalla's bundled content blocker lists.

Downloads the filter lists named in SOURCES, converts the Adblock Plus style rules that
Safari content blockers can express into WebKit content rule list JSON, dedupes them, and
writes the results plus a manifest into Zalla/Blocklists.

Only generated JSON data ships in the app. This script is an offline build tool.

Usage:
    python3 tools/blocklists/build_blocklists.py            # download and build
    python3 tools/blocklists/build_blocklists.py --cache DIR  # reuse downloaded copies in DIR
    python3 tools/blocklists/build_blocklists.py --validate   # also compile with WebKitGTK if present

Requirements: Python 3.9+. Optional: soupsieve (selector validation), WebKitGTK 6 via PyGObject
(--validate compiles every output with the real WebKit content rule compiler).
"""

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.request
import zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "Zalla", "Blocklists")

# License notes (checked Sep 2026):
# EasyList, EasyPrivacy: dual GPLv3+ / CC BY-SA 3.0+ (https://easylist.to/pages/licence.html).
#   Zalla uses them under CC BY-SA 3.0 with attribution to "The EasyList authors".
# EasyList Cookie List, Fanboy's Annoyance List: file headers say CC BY 3.0; they live in the
#   EasyList repository, which is dual GPLv3+ / CC BY-SA 3.0+. Used under CC BY-SA 3.0.
# Not used: Peter Lowe's list (no open license, commercial use needs permission),
#   AdGuard filters (GPLv3 only), DuckDuckGo Tracker Radar tds (CC BY-NC-SA, non-commercial).
SOURCES = {
    "easylist": "https://easylist.to/easylist/easylist.txt",
    "easyprivacy": "https://easylist.to/easylist/easyprivacy.txt",
    "cookie": "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
    "annoyance": "https://secure.fanboy.co.nz/fanboy-annoyance.txt",
}

# Output lists. Free lists are on by default; paid lists need Zalla Unlock.
LISTS = [
    {"id": "privacy", "tier": "free", "title": "Trackers"},
    {"id": "ads-basic", "tier": "free", "title": "Common ad networks"},
    {"id": "ads-extra", "tier": "paid", "title": "Full ad blocking"},
    {"id": "cosmetic", "tier": "paid", "title": "Hide ad spaces"},
    {"id": "annoyances", "tier": "paid", "title": "Cookie banners and annoyances"},
]

# Apple allows 150,000 rules per compiled list. Stay under it with room to spare.
MAX_RULES_PER_LIST = 140000
SELECTORS_PER_RULE = 100

BLOCK_TYPES = ["image", "style-sheet", "script", "font", "raw", "svg-document", "media", "ping"]
TYPE_MAP = {
    "script": "script",
    "image": "image",
    "stylesheet": "style-sheet",
    "font": "font",
    "media": "media",
    "xmlhttprequest": "raw",
    "websocket": "raw",
    "object": "raw",
    "other": "raw",
    "ping": "ping",
    "popup": "popup",
}
IGNORED_OPTIONS = {"important", "all"}
UNSUPPORTED_OPTIONS = {
    "csp", "redirect", "redirect-rule", "removeparam", "queryprune", "rewrite", "header",
    "sitekey", "badfilter", "denyallow", "to", "method", "webrtc", "replace", "urltransform",
    "permissions", "inline-script", "inline-font", "genericblock", "empty", "mp4", "cname",
    "strict1p", "strict3p", "urlskip", "reason", "ipaddress", "uritransform", "specifichide",
    "shide", "ghide", "ehide", "doc", "frame", "css", "xhr", "1p", "3p", "first-party",
}
EXTENDED_SELECTOR_MARKERS = [
    ":-abp-", ":has-text(", ":contains(", ":xpath(", ":matches-css", ":upward(", ":remove(",
    ":style(", ":matches-attr(", ":min-text-length(", ":watch-attr(", ":matches-path(",
    ":others(", ":nth-ancestor(", ":matches-media(", ":if(", ":if-not(", "[-ext-",
    ":matches-property(", ":remove-attr(", ":remove-class(", ":-webkit-", "+js(",
]

COSMETIC_RE = re.compile(r"^([^/|@$^*#]*?)(#@?[?$%]?#|\$@?\$)(.+)$")
OPTIONS_RE = re.compile(r"\$(~?[\w-]+(?:=[^,]*)?(?:,~?[\w-]+(?:=[^,]*)?)*)$")
DOMAIN_ONLY_RE = re.compile(r"^\|\|([a-z0-9.-]+)\^?/?$")

try:
    import soupsieve
except ImportError:  # Selector validation is optional but recommended.
    soupsieve = None


def fetch(name, url, cache):
    if cache:
        path = os.path.join(cache, name + ".txt")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                return handle.read()
    request = urllib.request.Request(url, headers={"User-Agent": "Zalla blocklist builder"})
    with urllib.request.urlopen(request, timeout=60) as response:
        text = response.read().decode("utf-8")
    if cache:
        os.makedirs(cache, exist_ok=True)
        with open(os.path.join(cache, name + ".txt"), "w", encoding="utf-8") as handle:
            handle.write(text)
    return text


def list_version(text):
    match = re.search(r"^! Version: (\S+)", text, re.M)
    return match.group(1) if match else "unknown"


def domain_value(domain):
    """WebKit if-domain entry for a filter domain, or None when WebKit cannot express it."""
    domain = domain.strip().lower()
    if not domain or "*" in domain or "/" in domain:
        return None
    try:
        domain = domain.encode("idna").decode("ascii")
    except UnicodeError:
        return None
    if not re.match(r"^[a-z0-9.-]+$", domain):
        return None
    return "*" + domain


def split_domains(raw, separator):
    include, exclude = [], []
    for part in raw.split(separator):
        part = part.strip()
        if not part:
            continue
        target = exclude if part.startswith("~") else include
        value = domain_value(part.lstrip("~"))
        if value is None:
            return None
        target.append(value)
    return include, exclude


def pattern_to_regex(pattern):
    """Adblock pattern to WebKit url-filter regex, or None when it cannot be expressed."""
    if not pattern.isascii():
        return None
    domain_anchor = pattern.startswith("||")
    if domain_anchor:
        pattern = pattern[2:]
    start_anchor = not domain_anchor and pattern.startswith("|")
    if start_anchor:
        pattern = pattern[1:]
    end_anchor = pattern.endswith("|")
    if end_anchor:
        pattern = pattern[:-1]
    if "|" in pattern:
        return None
    if domain_anchor and re.match(r"^[A-Za-z0-9.-]+\^$", pattern):
        # Plain host rules: WebKit URLs always have a / or : after the host.
        return "^[a-z-]+://([^/]+\\.)?" + pattern[:-1].lower().replace(".", "\\.") + "[/:]"
    out = []
    for index, char in enumerate(pattern):
        if char == "*":
            out.append(".*")
        elif char == "^":
            out.append("([/:?=&].*)?$" if index == len(pattern) - 1 else "[/:?=&]")
        elif char in ".+?{}()[]\\$":
            out.append("\\" + char)
        else:
            out.append(char)
    body = "".join(out)
    if domain_anchor:
        body = "^[a-z-]+://([^/]+\\.)?" + body
    elif start_anchor:
        body = "^" + body
    while body.startswith(".*"):
        body = body[2:]
    if body.endswith("([/:?=&].*)?$") and end_anchor:
        return None
    if end_anchor and not body.endswith("$"):
        body += "$"
    while body.endswith(".*") and not body.endswith("\\.*"):
        body = body[:-2]
    plain = re.sub(r"[\\^$]", "", body)
    if len(plain) < 3:
        return None
    return body


def parse_network(line):
    """Returns (is_exception, trigger, special) or None. special is 'document', 'elemhide',
    'generichide' for page level exceptions, else None."""
    exception = line.startswith("@@")
    if exception:
        line = line[2:]
    if line.startswith("/") and line.endswith("/") and len(line) > 2:
        return None  # Regex rules use syntax WebKit does not support.
    options = []
    match = OPTIONS_RE.search(line)
    if match:
        options = match.group(1).split(",")
        line = line[: match.start()]
    trigger = {}
    types = []
    negated_types = []
    subdocument = False
    special = None
    for option in options:
        name, _, value = option.partition("=")
        negated = name.startswith("~")
        bare = name.lstrip("~").lower()
        if bare in IGNORED_OPTIONS:
            continue
        if bare == "third-party":
            trigger["load-type"] = ["first-party" if negated else "third-party"]
        elif bare in ("domain", "from"):
            domains = split_domains(value, "|")
            if domains is None:
                return None
            include, exclude = domains
            if include and exclude:
                return None
            if include:
                trigger["if-domain"] = include
            elif exclude:
                trigger["unless-domain"] = exclude
        elif bare == "match-case":
            trigger["url-filter-is-case-sensitive"] = True
        elif bare == "subdocument":
            if negated:
                return None
            subdocument = True
        elif bare in ("document", "elemhide", "generichide"):
            if not exception or negated:
                return None
            special = bare
        elif bare in TYPE_MAP:
            (negated_types if negated else types).append(TYPE_MAP[bare])
        else:
            return None
    if special:
        # Page level exceptions apply to the whole site, so they match on the page domain.
        host = DOMAIN_ONLY_RE.match(line.lower())
        value = domain_value(host.group(1)) if host else None
        if value is None or trigger:
            return None
        return exception, {"url-filter": ".*", "if-domain": [value]}, special
    regex = pattern_to_regex(line)
    if regex is None:
        return None
    trigger["url-filter"] = regex
    if negated_types and not types:
        types = [t for t in BLOCK_TYPES if t not in negated_types]
    elif not types and not subdocument:
        if not DOMAIN_ONLY_RE.match(line.lower()):
            types = list(BLOCK_TYPES)
    triggers = []
    if types:
        typed = dict(trigger)
        typed["resource-type"] = sorted(set(types))
        triggers.append(typed)
    if subdocument:
        frame = dict(trigger)
        frame["resource-type"] = ["document"]
        frame["load-context"] = ["child-frame"]
        triggers.append(frame)
    if not triggers:
        triggers.append(trigger)
    return exception, triggers, None


def selector_ok(selector):
    if not selector.isascii() or len(selector) > 1000:
        return False
    lowered = selector.lower()
    if any(marker in lowered for marker in EXTENDED_SELECTOR_MARKERS):
        return False
    if soupsieve is not None:
        try:
            soupsieve.compile(selector)
        except Exception:
            return False
    return True


def rule_key(rule):
    return json.dumps(rule, sort_keys=True, separators=(",", ":"))


class Converter:
    def __init__(self):
        self.blocks = []
        self.exceptions = []
        self.page_exceptions = {"document": [], "elemhide": [], "generichide": []}
        self.generic_selectors = []
        self.generic_negated = {}
        self.specific = {}
        self.hide_exceptions = {}
        self.skipped = 0

    def add_text(self, text):
        for raw in text.splitlines():
            line = raw.strip()
            if not line or line.startswith("!") or line.startswith("["):
                continue
            cosmetic = COSMETIC_RE.match(line)
            if cosmetic:
                self.add_cosmetic(*cosmetic.groups())
                continue
            if "#" in line and "##" in line:
                self.skipped += 1
                continue
            parsed = parse_network(line)
            if parsed is None:
                self.skipped += 1
                continue
            exception, trigger, special = parsed
            if special:
                self.page_exceptions[special].append(trigger)
            elif exception:
                self.exceptions.extend(trigger)
            else:
                self.blocks.append((line, trigger))

    def add_cosmetic(self, domains, separator, selector):
        if separator not in ("##", "#@#") or not selector_ok(selector):
            self.skipped += 1
            return
        parsed = split_domains(domains, ",") if domains else ([], [])
        if parsed is None:
            self.skipped += 1
            return
        include, exclude = parsed
        if separator == "#@#":
            if include and not exclude:
                self.hide_exceptions.setdefault(selector, set()).update(include)
            else:
                self.skipped += 1
            return
        if include and exclude:
            self.skipped += 1
        elif include:
            self.specific.setdefault(tuple(sorted(include)), []).append(selector)
        elif exclude:
            self.generic_negated.setdefault(selector, set()).update(exclude)
        else:
            self.generic_selectors.append(selector)

    def network_rules(self, only_domains=None):
        """Blocking rules then exceptions. only_domains True keeps pure domain rules, False the rest."""
        rules = []
        for line, triggers in self.blocks:
            is_domain = bool(DOMAIN_ONLY_RE.match(line.lower().split("$")[0]))
            if only_domains is not None and is_domain != only_domains:
                continue
            for trigger in triggers:
                rules.append({"trigger": trigger, "action": {"type": "block"}})
        return rules, self.exception_rules()

    def exception_rules(self):
        rules = [{"trigger": t, "action": {"type": "ignore-previous-rules"}} for t in self.exceptions]
        rules += [{"trigger": t, "action": {"type": "ignore-previous-rules"}}
                  for t in self.page_exceptions["document"]]
        return rules

    def cosmetic_rules(self):
        rules = []
        grouped = []
        for selector in dedupe(self.generic_selectors):
            excluded = self.hide_exceptions.get(selector, set()) | self.generic_negated.pop(selector, set())
            if excluded:
                rules.append(hide_rule([selector], unless=sorted(excluded)))
            else:
                grouped.append(selector)
        for selector, excluded in sorted(self.generic_negated.items()):
            excluded = excluded | self.hide_exceptions.get(selector, set())
            rules.append(hide_rule([selector], unless=sorted(excluded)))
        for start in range(0, len(grouped), SELECTORS_PER_RULE):
            rules.append(hide_rule(grouped[start:start + SELECTORS_PER_RULE]))
        page_level = self.page_exceptions["elemhide"] + self.page_exceptions["generichide"]
        tail = [{"trigger": t, "action": {"type": "ignore-previous-rules"}} for t in page_level]
        specific = []
        for domains, selectors in sorted(self.specific.items()):
            kept = [s for s in dedupe(selectors) if not set(domains) & self.hide_exceptions.get(s, set())]
            for start in range(0, len(kept), SELECTORS_PER_RULE):
                specific.append(hide_rule(kept[start:start + SELECTORS_PER_RULE], only=list(domains)))
        final = [{"trigger": t, "action": {"type": "ignore-previous-rules"}}
                 for t in self.page_exceptions["elemhide"]]
        return rules + tail + specific + final


def dedupe(items):
    seen = set()
    result = []
    for item in items:
        key = item if isinstance(item, str) else rule_key(item)
        if key not in seen:
            seen.add(key)
            result.append(item)
    return result


def hide_rule(selectors, only=None, unless=None):
    trigger = {"url-filter": ".*"}
    if only:
        trigger["if-domain"] = only
    if unless:
        trigger["unless-domain"] = unless
    return {"trigger": trigger, "action": {"type": "css-display-none", "selector": ", ".join(selectors)}}


def chunk(blocks, tail):
    blocks = dedupe(blocks)
    tail = dedupe(tail)
    room = MAX_RULES_PER_LIST - len(tail)
    if room <= 0:
        raise SystemExit("Too many exception rules for one list")
    if not blocks:
        return [tail] if tail else []
    return [blocks[start:start + room] + tail for start in range(0, len(blocks), room)]


def write_outputs(outputs, sources):
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in os.listdir(OUT_DIR):
        if name.startswith("blocklist-"):
            os.remove(os.path.join(OUT_DIR, name))
    manifest = {"sources": sources, "lists": []}
    written = []
    for spec in LISTS:
        parts = outputs[spec["id"]]
        entry = dict(spec)
        entry["parts"] = []
        for index, rules in enumerate(parts):
            name = spec["id"] if len(parts) == 1 else "%s-%d" % (spec["id"], index + 1)
            data = json.dumps(rules, separators=(",", ":"), sort_keys=True).encode("ascii")
            # Raw DEFLATE, which the app reads with NSData.decompressed(using: .zlib).
            packer = zlib.compressobj(9, zlib.DEFLATED, -15)
            packed = packer.compress(data) + packer.flush()
            path = os.path.join(OUT_DIR, "blocklist-%s.deflate" % name)
            with open(path, "wb") as handle:
                handle.write(packed)
            written.append((path, data))
            entry["parts"].append({
                "name": name,
                "resource": "blocklist-%s" % name,
                "rules": len(rules),
                "bytes": len(data),
                "packedBytes": len(packed),
                "version": hashlib.sha256(data).hexdigest()[:12],
            })
        manifest["lists"].append(entry)
    with open(os.path.join(OUT_DIR, "blocklists-manifest.json"), "w", encoding="ascii") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")
    return manifest, written


def validate(paths):
    try:
        import gi
        gi.require_version("WebKit", "6.0")
        from gi.repository import GLib, WebKit
    except (ImportError, ValueError):
        print("WebKitGTK not available; skipping compile check")
        return True
    import tempfile
    store = WebKit.UserContentFilterStore.new(tempfile.mkdtemp())
    loop = GLib.MainLoop()
    results = {}

    def finished(source, result, path):
        try:
            source.save_finish(result)
            results[path] = "compiled"
        except GLib.Error as error:
            results[path] = "FAILED: %s" % error.message
        if len(results) == len(paths):
            loop.quit()

    for index, (path, data) in enumerate(paths):
        store.save("check%d" % index, GLib.Bytes.new(data), None, finished, path)
    loop.run()
    ok = True
    for path, _ in paths:
        print("  %s: %s" % (os.path.basename(path), results[path]))
        ok = ok and results[path] == "compiled"
    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--cache", help="directory for downloaded list copies")
    parser.add_argument("--validate", action="store_true", help="compile outputs with WebKitGTK")
    args = parser.parse_args()
    if soupsieve is None:
        print("warning: soupsieve not installed, selectors are not syntax checked", file=sys.stderr)

    texts = {name: fetch(name, url, args.cache) for name, url in SOURCES.items()}
    sources = {name: {"url": SOURCES[name], "version": list_version(texts[name])} for name in SOURCES}

    easylist = Converter()
    easylist.add_text(texts["easylist"])
    privacy = Converter()
    privacy.add_text(texts["easyprivacy"])
    annoyances = Converter()
    annoyances.add_text(texts["cookie"])
    annoyances.add_text(texts["annoyance"])

    outputs = {}
    blocks, tail = privacy.network_rules()
    outputs["privacy"] = chunk(blocks, tail)
    blocks, tail = easylist.network_rules(only_domains=True)
    outputs["ads-basic"] = chunk(blocks, tail)
    blocks, tail = easylist.network_rules(only_domains=False)
    outputs["ads-extra"] = chunk(blocks, tail)
    outputs["cosmetic"] = chunk(easylist.cosmetic_rules(), [])
    blocks, tail = annoyances.network_rules()
    outputs["annoyances"] = chunk(blocks + annoyances.cosmetic_rules(), tail)

    manifest, paths = write_outputs(outputs, sources)
    for entry in manifest["lists"]:
        for part in entry["parts"]:
            print("%-14s %-5s %7d rules %9d bytes (%d packed)"
                  % (part["name"], entry["tier"], part["rules"], part["bytes"], part["packedBytes"]))
    print("skipped lines: easylist %d, easyprivacy %d, annoyances %d"
          % (easylist.skipped, privacy.skipped, annoyances.skipped))
    if args.validate and not validate(paths):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
