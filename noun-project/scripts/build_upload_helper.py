"""Build a self-contained HTML upload helper: per icon, download the SVG and copy title/tags."""
import csv, html, json, sys, os
sets = [("Houseplant Care", "new_icons", "3_new_icons_metadata.csv"),
        ("Camping & Outdoor", "camping_icons", "4_camping_icons_metadata.csv")]
items = []
for name, folder, meta in sets:
    for r in csv.DictReader(open(meta, encoding="utf-8")):
        svg = open(os.path.join(folder, r["file"])).read().strip()
        items.append({"set": name, "file": r["file"], "title": r["title"], "tags": r["tags"], "svg": svg})
tpl = open(os.path.join(os.path.dirname(__file__), "upload_helper_template.html"), encoding="utf-8").read()
open(sys.argv[1], "w", encoding="utf-8").write(tpl.replace("/*DATA*/[]", json.dumps(items, ensure_ascii=False)))
print(len(items), "icons")
