"""Quick pre-upload check for glyph icon SVGs: single colour, no strokes/text/raster/masks."""
import re, sys, glob
bad_tags = ("<text", "<image", "<mask", "<clipPath", "<filter", "<linearGradient", "<radialGradient", "<style")
for f in sorted(glob.glob(sys.argv[1] + "/*.svg")):
    s = open(f).read(); issues = []
    issues += [f"금지 요소 {t}" for t in bad_tags if t in s]
    if re.search(r'stroke(-width)?="(?!none)', s): issues.append("stroke 사용 (면으로 변환 필요)")
    colours = set(re.findall(r'fill="(#[0-9a-fA-F]{3,6}|[a-z]+)"', s)) - {"none"}
    if len(colours) > 1: issues.append(f"색상 {len(colours)}개: {colours}")
    print(("OK  " if not issues else "FIX ") + f.split("/")[-1], "; ".join(issues))
