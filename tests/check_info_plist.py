#!/usr/bin/env python3
"""Structural checks on info.plist that `plutil -lint` cannot do.

Catches the v2.0 launch bug: a Run Script node that names a `scriptfile` but
is not in External Script mode (type 8) runs its (empty) inline script instead.
"""
import os
import plistlib
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTERNAL_SCRIPT = 8

with open(os.path.join(ROOT, "info.plist"), "rb") as fh:
    plist = plistlib.load(fh)

objects = {o["uid"]: o for o in plist["objects"]}
connections = plist.get("connections", {})
errors = []

for uid, obj in objects.items():
    if obj["type"] != "alfred.workflow.action.script":
        continue
    cfg = obj.get("config", {})
    scriptfile = cfg.get("scriptfile", "")
    if not scriptfile:
        errors.append(f"{uid}: Run Script has no scriptfile (inline scripts are not allowed in v2)")
        continue
    if cfg.get("type") != EXTERNAL_SCRIPT:
        errors.append(f"{uid}: scriptfile={scriptfile} but type={cfg.get('type')} (must be {EXTERNAL_SCRIPT} = External Script)")
    if cfg.get("script"):
        errors.append(f"{uid}: inline script must be empty when scriptfile is set")
    if cfg.get("scriptargtype") != 1:
        errors.append(f"{uid}: scriptargtype must be 1 (argv)")
    path = os.path.join(ROOT, scriptfile)
    if not os.path.isfile(path):
        errors.append(f"{uid}: scriptfile {scriptfile} does not exist")
    else:
        if not os.access(path, os.X_OK):
            errors.append(f"{uid}: {scriptfile} is not executable (chmod +x)")
        with open(path, "rb") as fh:
            if not fh.readline().startswith(b"#!/usr/bin/osascript"):
                errors.append(f"{uid}: {scriptfile} must start with #!/usr/bin/osascript")

for src, conns in connections.items():
    if src not in objects:
        errors.append(f"connection from unknown uid {src}")
    for c in conns:
        if c["destinationuid"] not in objects:
            errors.append(f"{src} -> unknown uid {c['destinationuid']}")

keywords = {}
for uid, obj in objects.items():
    if obj["type"] == "alfred.workflow.input.keyword":
        keywords[obj["config"]["keyword"]] = uid
for required in ("{var:trigger_keyword}", "hide-diagnose"):
    if required not in keywords:
        errors.append(f"keyword {required} missing")

# Every keyword → exactly one Run Script → Notification showing {query}.
# A keyword may fan out to other objects too (hide-diagnose also fires a static progress notification).
for kw, uid in keywords.items():
    targets = [objects[c["destinationuid"]] for c in connections.get(uid, []) if c["destinationuid"] in objects]
    scripts = [o for o in targets if o["type"] == "alfred.workflow.action.script"]
    if len(scripts) != 1:
        errors.append(f"keyword {kw}: must be wired to exactly one Run Script (found {len(scripts)})")
        continue
    step2 = [c["destinationuid"] for c in connections.get(scripts[0]["uid"], [])]
    if not step2 or objects[step2[0]]["type"] != "alfred.workflow.output.notification":
        errors.append(f"keyword {kw}: Run Script not wired to a notification")
        continue
    if objects[step2[0]]["config"].get("text") != "{query}":
        errors.append(f"keyword {kw}: notification text must be {{query}} so failures are visible")

# hide-diagnose dumps for seconds: the keyword itself must fire a static "collecting…" notification.
diag_targets = [objects[c["destinationuid"]] for c in connections.get(keywords.get("hide-diagnose", ""), []) if c["destinationuid"] in objects]
progress = [o for o in diag_targets if o["type"] == "alfred.workflow.output.notification"]
if len(progress) != 1:
    errors.append(f"keyword hide-diagnose: needs exactly one direct progress notification (found {len(progress)})")
else:
    text = progress[0]["config"].get("text", "")
    if not text or "{query}" in text or progress[0]["config"].get("onlyshowifquerypopulated"):
        errors.append("keyword hide-diagnose: progress notification must have static text and show without a query")

if plist.get("version") != "2.0":
    errors.append(f"version is {plist.get('version')!r}, expected '2.0'")

if plist.get("category") != "Productivity":
    errors.append(f"category is {plist.get('category')!r}, expected 'Productivity' (Alfred sidebar category of the maintainer's install)")

if errors:
    print("\n".join("FAIL: " + e for e in errors))
    sys.exit(1)
print(f"ok   info.plist structure ({len(objects)} objects, {len(keywords)} keywords)")
