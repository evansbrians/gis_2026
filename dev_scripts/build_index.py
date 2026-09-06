#!/usr/bin/env python3
"""Build the course front-end index.html (a bookdown-style table of contents).

Run from the repo root:  python3 dev_scripts/build_index.py

Curated per-chapter metadata lives in CHAPTERS below. Everything else --
section titles, section anchors, chunk counts, word counts, the printed-page
estimate -- is derived from the .qmd sources and the rendered lesson HTML.
"""

import base64, glob, html, json, os, re, sqlite3, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

DROP = {"table of contents", "reference", "data for this lesson",
        "set up your session", "setup", "before you begin",
        "overview", "exercises", "take-home points"}

# Sections whose Quarto anchor we could not verify are still listed, unlinked.
def slugify(text):
    s = re.sub(r"^\s*\d+\.\s*", "", text).lower()
    s = s.replace("’", "").replace("‘", "").replace("\xa0", " ")
    s = re.sub(r"[^a-z0-9 \-_.]", "", s)
    s = re.sub(r"\s+", "-", s.strip())
    return re.sub(r"-{2,}", "-", s).strip("-")

def strip_number(text):
    return re.sub(r"^\s*\d+\.\s*", "", text).strip()

def clean_inline(text):
    """Render a markdown heading the way Quarto would display it."""
    text = text.replace("\xa0", " ")
    text = re.sub(r"\[([^\]]*)\]\{[^}]*\}", r"\1", text)   # [x]{.mono}
    text = re.sub(r"[`*]", "", text)                          # code / emphasis
    return re.sub(r"\s{2,}", " ", text).strip()

def sections_for(module, slug):
    """Level-2 headings of a lesson, from its .qmd (always current).

    Anchors are generated with slugify(), which reproduces Quarto's rule --
    verified against every rendered heading in modules 0-2.
    """
    t = open(f"modules/module_{module}/{slug}.qmd").read()
    t = re.sub(r"```.*?```", "", t, flags=re.S)
    out = []
    depth = 0
    for line in t.split("\n"):
        # Headings inside a ::: div are callout titles, not sections.
        if re.match(r"^:{3,}\s*$", line):
            depth = max(0, depth - 1)
            continue
        if re.match(r"^:{3,}\s*\S", line):
            depth += 1
            continue
        m = re.match(r"^##\s+(.+)$", line)
        if not m or depth:
            continue
        raw = m.group(1)
        text = clean_inline(raw)
        anchor = slugify(text)
        text = strip_number(text)
        if text.lower() in DROP:
            continue
        out.append([text, anchor])
    return out

def known_functions():
    con = sqlite3.connect("src/reference/course_reference.sqlite")
    names = {n for (n,) in con.execute("select function_name from functions")}
    con.close()
    return {n for n in names if re.fullmatch(r"[A-Za-z._][A-Za-z0-9._]*", n)}

KNOWN = known_functions()

def functions_used(module, slug):
    """Every course function called in the lesson's chunks (search index only)."""
    t = open(f"modules/module_{module}/{slug}.qmd").read()
    code = "\n".join(re.findall(
        r"^[ \t]*```\{(?:r|webr)[^\n]*\n(.*?)^[ \t]*```", t, re.S | re.M))
    used = {n for n in re.findall(r"([A-Za-z._][A-Za-z0-9._]*)\s*\(", code) if n in KNOWN}
    return " ".join(sorted(used))


# --------------------------------------------------------------------------
# The published inventory. The index is built FROM what is live on gh-pages,
# so it can never link to -- or even name -- an unpublished lesson.
# --------------------------------------------------------------------------
PAGES_BRANCH = "origin/gh-pages"

def published_pages():
    out = subprocess.run(["git", "ls-tree", "--name-only", "-r", PAGES_BRANCH],
                         capture_output=True, text=True, check=True).stdout
    return {line for line in out.split("\n") if line.endswith("/index.html")}

PUBLISHED = published_pages()

def is_published(slug_path):
    """slug_path is a site path such as 'module_1/1.3_objects/'."""
    return slug_path.rstrip("/") + "/index.html" in PUBLISHED

# --------------------------------------------------------------------------
# Curated metadata: blurb, kind and key functions per chapter.
# --------------------------------------------------------------------------
CHAPTERS = {
 "0.1": ("Setup", "Install and set up R and RStudio, adjust the global options for a comfortable and reproducible workflow, and get oriented in the four core panes.", []),
 "0.2": ("Tutorial", "How R's environment tracks the objects you create, how assignment and functions work, when quotation marks are and are not necessary, and how to install and load packages.", ["install.packages","library","ls","rm","str_c"]),
 "0.3": ("Tutorial", "The four atomic vector types you will use throughout the course — numeric, character, factor, and logical — and the common pitfalls that come with each.", ["class","typeof","factor","as.numeric","as.integer","as.character"]),
 "0.4": ("Tutorial", "How atomic vectors, matrices, lists, and data frames differ in dimension and homogeneity, how to construct and describe each, and how to read and write data with readr.", ["matrix","tibble","attributes","read_rds","write_rds","write_csv"]),
 "0.5": ("Tutorial", "Subset atomic vectors, matrices, lists, and data frames by position, by name, or by logical condition.", ["[...]","[[...]]","$","pluck","filter"]),
 "1.1": ("Orientation", "A road map for the course: where the resources live, how content is organized, and how to get unstuck.", []),
 "1.2": ("Setup", "The necessary setup steps before anything else — packages, renv, and the habits that make a coding session go well.", ["install.packages","tidyverse_update"]),
 "1.3": ("Tutorial", "An enhanced review of functions, environments, and data objects that builds the vocabulary the rest of the course depends on.", ["tribble","typeof","class","str","ls","environment"]),
 "1.4": ("Tutorial + video", "Read and write .csv and .rds files, peek inside .xlsx workbooks, and run the exploratory steps you should take every single time you read a file.", ["read_csv","read_rds","read_excel","write_rds","slice_head","summary"]),
 "1.5": ("Tutorial + video", "Global and recursive assignment, naming conventions, the pipe operator, and how to keep a global environment you can trust.", ["%>%","set_names","rename","str_c","rm","ls"]),
 "2.1": ("Tutorial", "Distinguish subsetting from extraction, then choose the right tool for rows, columns, values, and metadata.", ["filter","select","pull","pluck","distinct","slice_max"]),
 "2.2": ("Tutorial", "Create new columns and modify existing ones with dplyr — including the special case of NA values.", ["mutate","transmute","na_if","replace_na","row_number"]),
 "2.3": ("Tutorial", "Apply mutation, subsetting, and summary operations within groups, and tell per-operation grouping from persistent grouping.", ["group_by","summarize","count","n","ungroup"]),
 "2.4": ("Tutorial", "Combine and split columns and tables, join tables by shared keys, and pivot data between long and wide forms.", ["bind_rows","left_join","unite","separate_wider_delim","pivot_longer","pivot_wider"]),
 "2.5": ("Tutorial + video", "Build plots layer by layer — data, aesthetic mappings, geometries, scales, facets, labels, and themes.", ["ggplot","aes","geom_point","facet_wrap","scale_color_manual","labs","theme"]),
 "2.6": ("Tutorial", "Apply the three rules of tidy data to diagnose and repair the structural problems in a messy dataset.", ["pivot_longer","pivot_wider","separate_wider_delim","left_join"]),
 "3.1": ("Video, 13:17", "A video overview of the foundational GIS concepts: types of spatial data, file formats, and coordinate systems.", []),
 "3.2": ("Tutorial + video", "Read spatial files, pre-process simple features objects, and transform a coordinate reference system — the first full sf workflow of the course.", ["st_read","st_as_sf","st_crs","st_transform","st_cast","clean_names"]),
 "3.3": ("Tutorial", "Build sf points, lines, and polygons from the ground up, then convert one geometry type into another.", ["st_point","st_sfc","st_sf","st_cast","st_combine","geom_sf"]),
 "3.4": ("Tutorial", "What a CRS is, how to read its well-known text, how to transform one, and how to choose the right one for the task at hand.", ["st_crs","st_transform","lonlat_to_utm","geom_sf"]),
 "3.5": ("Tutorial", "Join attributes to a simple features object, then build static and interactive maps — basemaps, colors, titles, legends, and layered geometries.", ["tm_shape","tm_polygons","tm_dots","tm_basemap","tmap_mode","tm_legend"]),
 "3.6": ("Tutorial", "Aggregate geometries, compute centroids, distances, and areas, work with the units of spatial measurement, and build spatial buffers.", ["st_union","st_centroid","st_distance","st_area","st_buffer"]),
}

TITLES = {
 "0.1": "R and RStudio", "0.2": "Environment and functions", "0.3": "Values",
 "0.4": "Objects", "0.5": "Indexing",
 "1.1": "Course introduction", "1.2": "Getting started", "1.3": "R objects",
 "1.4": "Importing, exploring, and exporting data", "1.5": "Assignments",
 "2.1": "Introduction to subsetting and extraction", "2.2": "Introduction to mutation",
 "2.3": "Grouped operations and summarizing", "2.4": "Reshaping data frames",
 "2.5": "Introduction to data visualization with ggplot2", "2.6": "Tidy data",
 "3.1": "What is a GIS?", "3.2": "Introduction to spatial vector data",
 "3.3": "Constructing and converting simple features",
 "3.4": "The coordinate reference system", "3.5": "Introduction to tmap",
 "3.6": "Geometric operations with sf",
}

SLUGS = {
 "0.1": "0.1_intro_to_r_and_rstudio", "0.2": "0.2_environment_and_functions",
 "0.3": "0.3_values", "0.4": "0.4_objects", "0.5": "0.5_indexing",
 "1.1": "1.1_course_introduction", "1.2": "1.2_getting_started", "1.3": "1.3_objects",
 "1.4": "1.4_importing_exploring_exporting", "1.5": "1.5_assignments",
 "2.1": "2.1_subsetting_and_extraction", "2.2": "2.2_mutation",
 "2.3": "2.3_grouped_operations_and_summarize", "2.4": "2.4_reshaping_data_frames",
 "2.5": "2.5_intro_to_data_vis", "2.6": "2.6_tidy_data",
 "3.1": "3.1_what_is_a_gis", "3.2": "3.2_introduction_to_shapefiles",
 "3.3": "3.3_constructing_and_converting_shapefiles", "3.4": "3.4_crs",
 "3.5": "3.5_introduction_to_tmap", "3.6": "3.6_geometric_operations",
}

PARTS = [
 dict(n=0, kicker="Preliminary content", title="Before the course begins",
      startSlug="module_0/module_0_intro/", startLabel="Overview",
      note="No problem set",
      intro="Strongly recommended before Module 1. These chapters carry the core knowledge an early beginner in R should have, along with the parts of the language that experienced users most often overlook."),
 dict(n=1, kicker="Module 1", title="Foundations",
      startSlug="module_1/1.0_module_intro/", startLabel="Module introduction",
      note="Problem set: R foundations, due 30 Aug",
      intro="Concepts and tools before data. This module builds the conceptual understanding of R — functions, environments, objects, assignment — that everything after it rests on."),
 dict(n=2, kicker="Module 2", title="The tidyverse",
      startSlug="module_2/2.0_module_intro/", startLabel="Module introduction",
      note="Problem set: Counting coqui frogs, due 6 Sep",
      intro="The toolkit you will use for the rest of the course: subsetting and extraction, mutation, grouped summaries, reshaping and joining, ggplot2, and tidy data."),
 dict(n=3, kicker="Module 3", title="Introduction to spatial vector data",
      startSlug="module_3/3.0_module_intro/", startLabel="Module introduction",
      note="Problem set: Cicada emergence, due 10 Nov",
      intro="Our first foray into spatial data. The sf package end to end — reading and building geometries, the coordinate reference system, mapping with tmap, and geometric operations."),
]

# --------------------------------------------------------------------------
# Estimated reading time and printed-page equivalents.
# --------------------------------------------------------------------------
LINES_PER_PAGE = 46      # O'Reilly 7 x 9.25 trim, body text
WORDS_PER_LINE = 11.5
OUTPUT_RATIO = 1.15      # rendered output lines per line of source code

def lesson_stats(module, slug):
    t = open(f"modules/module_{module}/{slug}.qmd").read()
    chunks = len(re.findall(r"^[ \t]*```\{(?:r|webr)", t, re.M))
    code = 0
    for b in re.findall(r"^[ \t]*```\{(?:r|webr)[^\n]*\n(.*?)^[ \t]*```", t, re.S | re.M):
        code += len([l for l in b.split("\n") if l.strip() and not l.strip().startswith("#|")])
    words = len(re.sub(r"```.*?```", "", t, flags=re.S).split())
    figs = len(re.findall(r"!\[", t)) + len(re.findall(r"\{\{< video", t))
    heads = len(re.findall(r"^#{1,4} ", t, re.M))
    mins = max(10, int(round((words / 170 + chunks * 0.7) / 5) * 5))
    lines = words / WORDS_PER_LINE + code * 1.15 + code * OUTPUT_RATIO + figs * 16 + heads * 3
    return dict(chunks=chunks, words=words, mins=mins, lines=lines)

total = dict(chunks=0, words=0, lines=0.0, mins=0)
skipped = []

for part in PARTS:
    part["chapters"] = []
    for cid, slug in sorted(SLUGS.items()):
        if int(cid[0]) != part["n"]:
            continue
        site_path = f"module_{part['n']}/{slug}/"
        if not is_published(site_path):
            skipped.append(cid)
            continue
        kind, blurb, fns = CHAPTERS[cid]
        st = lesson_stats(part["n"], slug)
        for k in ("chunks", "words", "mins"):
            total[k] += st[k]
        total["lines"] += st["lines"]
        part["chapters"].append(dict(
            id=cid, title=TITLES[cid], slug=f"module_{part['n']}/{slug}/",
            kind=kind, blurb=blurb, mins=st["mins"],
            search=functions_used(part["n"], slug),
            sections=sections_for(part["n"], slug)))
    # module intros count toward the printed page estimate, not the chapter list
    intro_slug = "module_0_intro" if part["n"] == 0 else f"{part['n']}.0_module_intro"
    part["hasIntro"] = is_published(f"module_{part['n']}/{intro_slug}/")
    if part["hasIntro"]:
        st = lesson_stats(part["n"], intro_slug)
        total["chunks"] += st["chunks"]; total["words"] += st["words"]; total["lines"] += st["lines"]

# Drop any part with nothing published.
PARTS = [p for p in PARTS if p["chapters"]]

pages = round(total["lines"] / LINES_PER_PAGE / 10) * 10
chapters = sum(len(p["chapters"]) for p in PARTS)
hours = round(total["mins"] / 60)

logo = base64.b64encode(open("src/images/hex_complex.png", "rb").read()).decode()
tpl = open("dev_scripts/index_template.html").read()
out = (tpl.replace("__DATA__", json.dumps(PARTS, ensure_ascii=False, indent=1))
          .replace("__LOGO__", "data:image/png;base64," + logo))
os.makedirs("lessons", exist_ok=True)
open("lessons/index.html", "w").write(out)

print(f"lessons/index.html written: {chapters} published chapters, "
      f"{total['chunks']} chunks, {total['words']} words, ~{hours} hours, "
      f"~{pages} printed pages")
if skipped:
    print("not published, so omitted entirely: " + ", ".join(skipped))
