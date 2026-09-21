# Review: 6.1 Introduction to rasters with terra and stars

Reviewed: 8 Sep 2026 · Reviewer: Claude (independent second pass)

**Materials read.** `modules/module_6/6.1_introduction_to_rasters.qmd` (955 lines);
`brian_sandbox/module_review_protocol.md`; `brian_sandbox/lesson_voice_profile.md`
(headings in full, then §0.0, §2.1, §2.2, §2.55, §2.61, §2.69, §2.70, §2.71, §7, §8.1 read in
full); `modules/module_6/6.0_module_intro.qmd`; `modules/module_1/1.2`, `modules/module_3/3.2`,
`3.4`, `3.6`, `modules/module_5/5.1`, `5.3`, `5.4` (setup rituals, decision-tree blocks,
convention sampling); `src/reference/course_reference.sqlite` (`lessons`, `functions`,
`glossary`, `datasets`); `src/r/reference_lookup.R`; `brian_sandbox/claude_intructions/`
(`r_style_check.R`, `voice_check.py`).

**What was executed.** All 47 chunks were extracted with `checks/extract_chunks.py`; the 42
runnable ones ran in order from a clean session (`Rscript /tmp/rev.R`, exit 0, 16 s, no
warnings). Nine further verification scripts were written and run against the real data
(`/tmp/v1.R`–`/tmp/v9.R`). Behavioral claims were additionally checked against
`tools::Rd_db("terra")` for `project.Rd`, `resample.Rd`, `writeRaster.Rd`,
`aggregate.Rd` and `SpatRaster-class.Rd`, and against `terra::terraOptions()`. The Parsons
problem was unescaped and run both as its answer and with its distractor substituted.
Package versions on this machine: terra 1.7.65, tidyterra 0.5.2, stars 0.6.4, sf 1.0.15,
dplyr 1.1.4.

**Read-only.** Chunks 1–3 (`include: false` setup, the `lesson_metadata()` call) and the two
`eval: false` skeletons (lines 83–98, 740–748) were read, not run — `lesson_metadata()` was
run separately and returns correct text for all three datasets.

**Not verified.** Lessons 6.2–6.7 on disk are stale drafts from the previous structure and
were not used as a standard, per the review brief. `module_review_protocol.md` is truncated
between §4.6 and §4.9 — line 206 reads `ed by what it did.` and §4.7 (Voice) and §4.8 (Code
and style) are missing their headings and most of their text. Those two sections were scored
against `lesson_voice_profile.md` and `r_style_check.R` instead; anything the missing text
covered that those do not is not verified.

---

## Typo corrections applied

- line 121: `The **conflicted** package` → `The *conflicted* package` (packages take italics;
  the lesson italicizes *terra*, *tidyterra*, *stars*, *sf* and *dplyr* correctly in 30 other
  places).
- line 693: `**stars** is the package for that case` → `*stars* is the package for that case`
  (same rule).

That is the whole list. A mechanical sweep found **no** misspellings, **no** British spellings
(`grep -nE "colour|behaviour|summarise|analyse|centre|labelled|modelling|recognise|neighbour"`
→ empty), **no** doubled words (`grep -nEo "\b([a-z]+) \1\b"` → empty), and **no** clause
bracketed by a pair of em dashes (`grep -n "—.*—"` → empty, so §2.46 is clean). The mechanical
quality of this draft is very high.

---

## Scores

| Section | Weight | Score | Note |
|---|---|---|---|
| Scaffolding | 20% | 68% | order and cross-references are correct; a course term collides at line 26; `method =` is only defined behind a wrench |
| Technical accuracy | 20% | 64% | two Critical false claims and one Major; ~40 other claims verified correct |
| Reproducibility and verification | 10% | 78% | every chunk runs and every printed number matches; the decision-tree figure does not exist |
| Clarity | 10% | 76% | one self-contradicting sentence, one inconsistent characterization, one meaningless worked quantity |
| Voice | 10% | 60% | ~20 residual §2.69 violations after the rule was written on this draft today |
| Depth | 10% | 66% | the cover-the-wrench test fails for exercise 4, the Parsons problem and one take-home point |
| Exercises and assessment | 8% | 74% | every answer verified correct by running it; two items need a wrench box |
| Code and style compliance | 5% | 94% | `r_style_check.R` returns **no findings**; all four hard constraints met |
| Length | 5% | 18% | 4.1–4.5 hours against a 0.5–1.5 hour target |
| Structural conventions | 2% | 72% | section order and conventions correct; the figure and its include are missing |
| **Overall** | **100%** | **67%** | |

**Band: below 70 — restructure.** The score sits within two points of the 70 boundary, and the
single largest lever is length: splitting the lesson raises Length, Scaffolding and Depth
together and would move it into the 70–84 "substantial revision" band on its own.

**Hard stop.** Two Critical findings (lines 112/891 and 278) cap the overall score at 84
whatever the weighted mean. The mean is already below the cap, so the cap does not bind, but
the rule applies: a lesson that states something false about the console a student is looking
at is not a lesson with a note.

---

## Findings

### Critical

---

**C1 · lines 112 and 891 · The mechanism given for never attaching *terra* is false, and it is
backwards on both halves.**

> line 112: "Attaching a package rebinds those names to it, whichever `library()` call comes
> last is the one that holds them, **and nothing in the console reports the change.** A script
> that calls `extract()` expecting *tidyr*'s version and receives *terra*'s **does not error;
> it returns something else**, and the error that eventually appears is somewhere unrelated."

> line 891 (take-home): "`library(terra)` rebinds `extract()`, `intersect()` and `union()`
> **without reporting it**"

**Ran** (`/tmp/v3.R`):

```r
suppressPackageStartupMessages({library(tidyverse)})
capture.output(library(terra), type = "message")
```

**Returned:**

```
Attaching package: 'terra'

The following object is masked from 'package:tidyr':

    extract
```

R **does** report it, and `extract()` is the one name it reports.

**Ran** (`/tmp/v5.R`), to test the second half:

```r
library(tidyverse); a <- tibble(x = 1:3); b <- tibble(x = 2:4)
library(terra)
intersect(a, b)   # -> list()
union(a, b)       # -> [[1]] 1 2 3   [[2]] 2 3 4
extract(d, v, c("l","n"), "([a-z])-([0-9])")
# -> Error: error in evaluating the argument 'y' in selecting a method
#    for function 'extract': object 'v' not found
```

So the lesson has the two mechanisms swapped:

* `extract()` **is** reported by `library()`, and it **errors immediately** rather than
  returning something else.
* `intersect()` and `union()` are **not** reported — `terra` turns them into S4 generics, and R
  does not print a masking message for an S4 generic whose default method is the function it
  masks — and they are the pair that **silently returns a wrong answer** (`list()` instead of a
  one-column tibble).

The pedagogical conclusion (use the `terra::` prefix) is correct and worth keeping. The
mechanism under it is what a student will check against their own console the first time they
type `library(terra)`, and it will not match. Two named functions, `intersect()` and `union()`,
give the lesson exactly the silent-wrong-answer story it wants — it just attributes the story
to the wrong function.

*Suggested direction:* lead with `intersect()`/`union()` for the silent case, keep `extract()`
as the loud-but-confusing case, and drop "nothing in the console reports the change".

---

**C2 · line 278 · The rule given for the `source(s)` label is false, and the lesson's own
output contradicts it four sections later.**

> "**`source`** is the last line before the layer's own description. It names a *file* rather
> than `memory`, and the next section is about why. **On a raster with more than one source the
> label reads `source(s)`.**"

**Ran** (`/tmp/v6.R`), printing each case and grepping the label line:

| Object | Label printed |
|---|---|
| `dem` — 1 layer, 1 file | `source      : scbi_dem.tif` |
| `dc` — **4 layers, 1 file** | `source      : dc_stack.tif` |
| `terra::aggregate(dem, 50)` — **1 layer, in memory** | `source(s)   : memory` |
| two rasters written to two files, `c()`-ed | `sources     : filef22264d67ea.tif` … |
| `c(dem, dem * 2)` — file + memory | `sources     : scbi_dem.tif` … |

`source(s)` is what appears when the values are **in memory**, not when there is more than one
source. With more than one source the label reads `sources`, plural and without parentheses.

This is not academic: the lesson's own chunk at line 626 prints `campus`, whose output reads
`sources     :` over two lines, and the seven chunks at lines 420, 435, 497, 534, 571, 633 and
640 all print `source(s)   : memory` for **single**-source rasters. A student following line 278 as
a diagnostic will read every one of those backwards — and line 310 asks them to use exactly
this line as a diagnostic ("**Reading `source` is how you tell a raster whose values are on
disk from one whose values are in your session**").

*Suggested direction:* the true and useful rule is the one line 310 already states — `memory`
versus a filename. The parenthetical about the label's plural forms is not needed and is what
went wrong; cutting it fixes the finding.

---

### Major

---

**M1 · line 479 · "`disagg()` … recovers the grid's shape" contradicts the output printed two
sentences above it.**

> "750 by 780 against 745 by 778. **`disagg()` is not an undo.** It splits each cell into a
> block of identical values, so **it recovers the grid's shape** and never the detail that
> `aggregate()` averaged away."

**Ran** (chunks 27 and 28 of the lesson, plus `/tmp/v9.R`):

```
disagg round trip -> dim: 750 780 1   res: 3.08642e-05 3.08642e-05
dem               -> dim: 745 778 1   res: 3.08642e-05 3.08642e-05
extents equal?    -> FALSE
```

The shape is exactly what is **not** recovered — that is the point of the whole paragraph
("the round trip does not come home", line 460). What is recovered is the resolution. The
sentence as written tells the reader the opposite of what the two chunks just showed them, and
of what the lesson's own `fig-alt` says ("aggregate() rounds the number of blocks up so the
round trip does not return the grid").

*Suggested direction:* "it recovers the cell size and never the detail".

---

**M2 · line 26 · "features" is used in its everyday sense two modules after the course bolded
it as a course term, and "surface" is introduced in passing and then leaned on.**

> "**Rasters represent data across a continuous surface**, and they are used to characterize
> environmental **features** such as land cover, elevation and temperature."

`modules/module_3/3.2_introduction_to_shapefiles.qmd` line 22: "Spatial vector data represent
discrete geographic **features** as **points**, **lines**, or **polygons**. A feature is a
single thing that the data describe, such as one county or one sampling site."
`lesson_voice_profile.md` §7 lists **features** (geometries) among the vocabulary the course
insists on.

This is the exact collision recorded in `lesson_voice_profile.md` §2.71 (dated 8 Sep 2026),
which quotes this sentence and concludes "**Both sentences were cut.**" The second sentence
("Modules 3 through 5 built the tools for features") is indeed gone from the draft; the first —
the one carrying both faults — is still line 26. §2.71's second note applies to it too: "the
students have yet to be introduced to the term 'surface'", and the next sentence treats
surfaces as an established category.

---

**M3 · lines 502, 509–521, 895, 918–920, 922–939 · The cover-the-wrench test fails: `method =`
is never defined in the main line, and three assessed items depend on the box that defines it.**

Protocol §4.5: "**Nothing behind the wrench is required knowledge.** Cover every under-the-hood
box: a beginner must still be able to do everything the lesson asks, including every exercise."

`method = "bilinear"` first appears in a **code chunk** at line 502 with no main-line gloss.
The only definition in the lesson is inside the `::: mysecret` box at line 518: "`method =
"bilinear"` averages the four nearest cells, which is right for a quantity. `method = "near"`
copies the nearest cell, which is the only correct choice for a class."

Covering that box, the following become unanswerable:

* **Exercise 4** (line 918): "A land cover raster is projected with `method = "bilinear"`. What
  is wrong with the result?"
* **Exercise 5, the Parsons problem** (line 922): "One line supplies the resampling method that
  a class needs rather than the one a quantity needs. Leave it in the trash." Its two candidate
  lines differ only in `method = "near"` versus `method = "bilinear"`.
* **Take-home point** (line 895): "`method = "near"` rather than `"bilinear"` whenever the
  values are classes."

A take-home point drawn wholly from a wrench box is itself a §4.5 finding; three dependencies
on one box is a structural one.

*Suggested direction:* promote the two-sentence definition of `method =` into the main line at
line 507, where `resample()` is being introduced with that argument already in the call, and
leave the *terra*-defaults material and the `nlcd`-code arithmetic in the box.

---

**M4 · line 878 · The decision-tree figure and its PDF include do not exist.**

```
$ ls src/images/decision_trees/ | grep raster
reading_a_raster.svg
$ grep -rl "raster_model" .
./modules/module_6/6.1_introduction_to_rasters.qmd
./modules/module_6/lesson_6.1_review.md
```

`src/images/decision_trees/raster_model.svg` is referenced nowhere else in the repository and
does not exist; `src/includes/decision_tree_pdfs/raster_model.qmd`, included at line 880, does
not exist either. Every SVG referenced by modules 3, 4 and 5 **is** present in that directory
(`working_with_points.svg`, `building_a_track.svg`, `classifying_spatial_data.svg`,
`cartography_ii.svg`, `reports_that_scale.svg`, `choosing_a_crs.svg`, …), so this is a genuine
gap rather than an artifact of the mirror. The module-6 SVGs that do exist —
`reading_a_raster.svg`, `matching_grids.svg`, `map_algebra.svg`, `terrain.svg` — belong to the
superseded structure.

"Putting it all together" is a required section (§4.10) and it is currently a broken image, a
missing include, and a ~300-word `fig-alt` describing a drawing nobody can see. To its credit
the alt text is accurate: every claim in it was checked against the lesson's output and none is
wrong, and it is the one place in the lesson with no §2.69 violations.

---

**M5 · whole lesson · Length: 4.1–4.5 hours against a 0.5–1.5 hour target.**

Counted mechanically from the source: 5,073 prose words (code chunks stripped, `fig-alt` and
attribute braces stripped, MCQ option text retained); 47 chunks of which 3 are hidden, leaving
44 visible; 23 functions new to the course; 4 `mysecret` boxes; 4 "Now you!" challenges; 5
"Check your understanding" panels holding 17 MCQ/true-false items in total; 1 Parsons problem.

The 23 new functions were checked against modules 0–5 with
`grep -rEho "\bNAME\(" modules/module_0 … modules/module_5` returning 0: `rast`, `xyFromCell`,
`cellFromXY`, `res`, `aggregate`, `ncell`, `writeRaster`, `as.points`, `tempfile`, `file.size`,
`inMemory`, `global`, `cellSize`, `project`, `disagg`, `resample`, `not.na`, `datatype`,
`describe`, `read_stars`, `str_subset`, `geom_spatraster`, `scale_fill_hypso_c`.

At the protocol's default rates:

| Element | Count | Rate | Minutes |
|---|---|---|---|
| Prose | 5,073 words | 130 w/min | 39.0 |
| Code chunks | 44 | 1.5 min | 66.0 |
| New functions | 23 | 3 min | 69.0 |
| Under-the-hood boxes | 4 | 2 min | 8.0 |
| "Now you!" challenges | 4 | 8–12 min | 32–48 |
| Quiz / checkpoint items | 17 | 1.5 min | 25.5 |
| Parsons problem | 1 | 8–12 min | 8–12 |
| **Total** | | | **247.5–267.5 min = 4.1–4.5 h** |

The module target is 7–10 hours for seven lessons; 6.1 alone would spend half of it. The fix is
**to split, not to cut** — the material is good and the trouble is that seven models are stacked
in one sitting. The natural seam is after "A resolution is not always a distance": everything
from "Because there is no stored position, there is no key" through "A second measurement is a
second layer" (`project()`, `aggregate()`, `disagg()`, `resample()`, `filter()`, `c()`,
`select()`/`mutate()` — 8 of the 23 new functions and roughly half the runtime) is a lesson of
its own, and *stars* plus `writeRaster()`/`datatype`/compression is arguably a third.

---

**M6 · ~20 places · The §2.69 personification sweep has not been run past the opening
paragraph.**

`lesson_voice_profile.md` §2.69 was written on 8 Sep 2026 **about this draft**, states the rule
as "**A raster, a file, a grid, a cell, a layer, a value, a table or an object is never the
subject of an action verb**", and closes "**The sweep is mechanical and should be run on every
draft.**" The opening paragraph was repaired (line 28 is now the version §2.69 records as
passing). The rest of the lesson was not.

`grep -n -iE "\b(stores|store|holds|hold|records|keeps|carries|carry|behaves|arrives|refuses|wants|waits|lives|spends)\b"` returns, among others:

| Line | Text |
|---|---|
| 706 | "A `SpatRaster` **stores** the same orientation and does not print it." |
| 352 | "The elevation model **reports** a resolution of `3.08642e-05`." |
| 382 | "*terra* **refuses** when the arrays do not line up" — *refuses* is on §2.1's explicit list |
| 684 | "The District file we read at the start **holds** four layers" |
| 702 | "The print **carries** the **attributes**, which are the variables the cube **holds**" |
| 704 | "The `delta` entry and the attribute name each **carry** something the printed `SpatRaster` never **showed** us." |
| 750 | "It is the type the elevation model already **carries** on disk" |
| 830 | "the land cover layer, which **holds** a small set of whole numbers" |
| 518 | "An averaged class code **arrives** looking like a class" |
| 310 | "the `source` line **reads** `memory`" |
| 577, 587, 652, 671, 345 | "every cell … now **holds** `NA`" / "the cells that **hold** a value" (×4) |
| 38 | "choosing a data type that **keeps** its values" |
| 312 | "a raster that **holds** calculated values"; "`source` **names** a file" |
| 569 | "a rectangle has no way to **hold** a gap" |
| 892 | take-home: "the `source` line **report** which state an object is in" |
| 287, 283, 865 | MCQ stems: "a `SpatRaster` **stores** the coordinates"; "How many cells does it **hold**?"; "A raster … **holds** values from 0 to 93.99999" |

Line 706 is verbatim the construction §2.69 records Brian rejecting ("A raster records a value
… this is again personification"). The quotation from `SpatRaster-class.Rd` at line 294 is a
quotation and is correctly exempt.

The repo's own `voice_check.py` independently returns 6 flags on the file (lines 121, 300, 382,
514, 518, 788) — it implements §2.1 but not §2.69's data-noun sweep, which is why the count
above is higher.

---

### Minor

---

**m1 · lines 828 and 860 · The lesson characterizes the same measurement two different ways.**

Line 828: "DEFLATE, a different method on the same values, reaches 1,935,732, **about a sixth
off** the uncompressed size." Line 860: "1,782,593 down to 91,557, from **the method that
returned almost nothing** on the elevation model."

**Ran** (chunks 46, 47): uncompressed 2,324,144; DEFLATE 1,935,732 → 16.7% saved; nlcd
1,782,593 → 91,557 → 94.9% saved. A sixth off is a real saving, not "almost nothing". Both
numbers are right; the two sentences do not agree about what they mean.

---

**m2 · line 520 · "the class codes are stored as plain integers" is not what the file stores.**

**Ran** (`/tmp/v9.R`): `terra::datatype(dc)` → `"FLT4S" "FLT4S" "FLT4S" "FLT4S"`, and
`terra::is.factor(dc$nlcd)` → `FALSE`. The values are whole numbers stored as four-byte
**floats**, not integers. The point the sentence is making — that *terra* sees them as numeric
and so defaults to `bilinear` — is correct and was verified against `project.Rd`
("`bilinear`: … This is the default if the first layer of `x` is numeric (not categorical)").
Only the word "integers" is wrong; "whole numbers" would be exact.

---

**m3 · line 865 · The MCQ stem overstates INT1U's usable range.**

"`datatype = "INT1U"`, which stores whole numbers from 0 to 255". `writeRaster.Rd` states:
"When writing integer values … the highest value is used [for `NA`] for unsigned values. This
can be a problem with byte data (between 0 and 255) as the value 255 is reserved for `NA`."
The usable range is 0–254 unless `NAflag` is set. The answer is unaffected — I verified it:
writing `dc$canopy` (max 93.99999) with `datatype = "INT1U"` and reading it back gives
`min 0, max 93`, with the NA count unchanged at 264,742 (`/tmp/v2.R`), so "Whole numbers from
0 to 93" is right and "NA everywhere above 93" is refutable.

---

**m4 · line 205 · The number stated is not readable from the output shown.**

"The y is identical and the x has moved by 0.0000308642." The two printed rows are
`-78.174` and `-78.17397`; the reader can get 0.00003 from them and no more, and `res(dem)`
prints `3.08642e-05` in scientific notation rather than as `0.0000308642`. §2.15 asks that
every example be anchored in printed output the reader can see. The claim is true — the step
is exactly the resolution by construction — but it is asserted rather than shown.

---

**m5 · lines 640–647 · `canopy_per_meter = canopy / elevation` is not a quantity.**

Percent canopy cover divided by elevation in meters has no interpretation, and the lesson does
not offer one ("Three layers now, and the third was calculated from the two above it without
using a coordinate"). §0.7 asks that every detail build understanding, and §2.9 asks that the
framing be grounded in ecology. `mutate()` on layers is worth showing; the example it is shown
with is the one thing in the lesson a student cannot make sense of. The `dc` stack next door
supplies real ones — canopy where impervious surface is low is already the next "Now you!".

---

**m6 · line 314 · A claim about the whole module that the module cannot yet support.**

"`global()` summarizes a whole layer, **and every count and summary in this module is made of
it**." Lessons 6.2–6.7 are being rewritten, so this is unverifiable at present and is the kind
of forward promise §2.24 warns against. `global()`'s own definition and example are fine.

---

**m7 · line 79 · The setup ritual drifts from the house wording.**

6.1: "then **run** `source_script_module_3.R` (see ***3.2 Introduction to spatial vector
data***)." 5.1, 5.4 and 5.3: "then **load** the module 3 source script." Items 1–4 are verbatim
and correct. §7 is emphatic that *attach* and *load* are course vocabulary with defined senses.

---

**m8 · lines 922–939 · The Parsons problem re-uses a live object name.**

Its final line is `campus <- c(dem_utm, canopy_utm)`, but `campus` already exists from line 612
as a different object (lon/lat NAD83, `dem` grid). **Ran** the assembled solution and the
distractor variant (`/tmp/v7.R`): both execute, the answer returns a 855 × 707 × 2 raster in
EPSG:32617 named `elevation`, `canopy`, and the distractor produces a visibly different
(nearest-neighbour) canopy layer, so the problem itself is sound. Only the name collides.

---

**m9 · comment length.** The eleven in-chunk comments average about seven words against the
r-style-formatter's ~5-word target (longest, line 243: "Write the same values both ways, into
temporary files:" — nine). All are one line and all describe only what the step does.

---

**m10 · checkpoint coverage.** §2.52 asks for a checkpoint per new function. `geom_spatraster()`
/ `scale_fill_hypso_c()` and `xyFromCell()` / `cellFromXY()` have neither a "Now you!" nor a
quiz item anywhere in the lesson. Every other new function is exercised somewhere.

---

## What is working, and should survive the revision

1. **The verification density is exceptional.** Every number stated in prose matches what the
   code prints. I checked all of them: 500316 resampled cells (line 187); 5,850 cells after
   `aggregate(fact = 10)`; 25,584 against 761,856 bytes and "thirty times" (29.8×) and "about
   four bytes per value" (4.37); the `[+] extents do not match` message verbatim; 79 × 82
   against 745 × 778 and "about nine times coarser" (9.393×); EPSG 32617; 855 × 707 and
   3.059843 m; 75 × 78; **152** missing cells — and 152 is exactly 78 + 75 − 1, one per block
   overhanging the edge, precisely as line 458 claims, with `dem` itself holding zero `NA`
   (`terra::global(is.na(dem), "sum")` → 0) and `na.rm = TRUE` bringing it to 0; 750 × 780
   against 745 × 778; 486,530 emptied and 93,080 remaining, which sum to 745 × 778 = 579,610;
   42,376; `FLT4S`; 2,369,174 / 421,211 and "under a fifth" (17.8%); 391 from 391.7271;
   `COMPRESSION=LZW`; 2,324,144 / 1,935,732 / 1,782,593 / 91,557. This is the standard §0.0
   item 1 asks for and it has been met almost everywhere.

2. **Two hard documentation claims are quoted exactly right.** The `SpatRaster` class quote at
   line 294 is verbatim from `SpatRaster-class.Rd`. The defaults claim at line 520 — "`project()`
   and `resample()` default to `near` when the **first layer** is categorical and to `bilinear`
   when it is numeric" — matches `project.Rd` and `resample.Rd` word for word, "first layer"
   included. So does `FLT4S` as the write default (`terra::terraOptions()$datatype`).

3. **The `nlcd` arithmetic in the wrench box is real, not illustrative.**
   `sort(unique(terra::values(dc$nlcd)))` → `11 21 22 23 24 31 41 42 43 52 71 81 82 90 95`. The
   codes are as listed and 31, the mean of 21 and 41, **is** in the scheme. That is the whole
   argument for `method = "near"` and it is made with the file in front of the reader.

4. **Every quiz answer is correct.** I ran or derived all 17. `ncell()` of a 500 × 400 × 3
   raster is 200,000 (run). `cellSize()` does vary in a geographic CRS (min 9.17349, max
   9.176408 m²), and a cell there is not square (x step 2.671 m, y step 3.432 m at SCBI), so
   both the `resolution` MCQ and its true/false are right. `c()` with mismatched extents errors
   (`[rast] extents do not match`), so exercise 8's FALSE is right. `filter()` before `select()`
   really does fail with `object 'imp' not found` (run). The INT1U item is right (see m3).

5. **The code style is cleaner than the course's own baseline.**
   `Rscript brian_sandbox/claude_intructions/r_style_check.R` returns **"no findings"** on this
   lesson and two findings on `5.1_focus_on_points.qmd`. All four hard constraints hold: no
   `library(terra)` in any chunk, no `setwd()`, `library(tidyverse)` last, `str_c()` rather than
   `paste0()`, and no base-R call where a tidyverse equivalent exists.

6. **Every cross-reference resolves.** Checked against the `lessons` table: ***1.2 Getting
   started***, ***3.2 Introduction to spatial vector data***, ***3.4 The coordinate reference
   system: Why it matters and how to use it***, ***4.3 Non-spatial joins***,
   ***Preliminary Lesson 3: Values***, ***Module 6: Raster data with terra*** — all six are
   exact title matches, all are bold-italic and none is a link, which is the convention. The
   `as.integer()` reference is especially well placed: 0.3 line 100 carries a `user-secret` box
   headed "`as.integer()` truncates, it does not round!", which is exactly the model line 788
   reuses.

7. **The organizing idea is the right one and it is carried through.** "The location of a cell
   is not part of the data" is stated once at line 28, in the form §2.69 records as passing, and
   then *earns* the key section ("there is no key" — the one causal heading whose claim survives
   testing), the grid-repair section, the stacking section and the storage comparison. The
   `xyFromCell()` → `res()` → `cellFromXY()` sequence at lines 193–222 is the best three
   paragraphs in the lesson: it makes an abstract claim about storage checkable in three printed
   lines.

8. **The opener has been fixed correctly.** §2.70/§2.71's consequence list is gone; "Material
   covered will include" does the table-of-contents job; and the seven items map one-to-one, in
   order, onto the seven `##` concept sections. Section order matches §4.10 exactly, take-home
   points precede the exercises, and the reference panel closes the file. The `mysecret` box on
   *conflicted* (lines 116–130) is a model of what belongs behind a wrench: complete, in one
   place, and nothing downstream needs it.

---

## Function inventory (appendix)

### Already introduced, treated correctly as known

| Function | Introduced in |
|---|---|
| `library()`, `source()` | 1.2 Getting started |
| `filter()`, `select()` | 2.1 Introduction to subsetting and extraction |
| `mutate()`, `rename()` | 2.2 Introduction to mutation |
| `ggplot()`, `theme_bw()` | 2.5 Introduction to data visualization with ggplot |
| `st_as_sf()`, `st_write()` | 3.2 Introduction to spatial vector data |
| `st_bbox()`, `st_as_sfc()`, `st_centroid()`, `st_coordinates()`, `lonlat_to_utm()`, `st_transform()` | 3.4 The coordinate reference system |
| `str_c()` | 2.x stringr material (core tidyverse) |
| `as.integer()` (referenced, not called) | Preliminary Lesson 3: Values |
| `c()`, `is.na()`, `dim()`, `names()` | Module 0 |

### New in this lesson (23), each with a definition and a worked example

`terra::rast()` · `geom_spatraster()` · `scale_fill_hypso_c()` · `terra::xyFromCell()` ·
`terra::cellFromXY()` · `terra::res()` · `terra::aggregate()` · `terra::ncell()` ·
`terra::writeRaster()` · `terra::as.points()` · `tempfile()` · `file.size()` ·
`terra::inMemory()` · `terra::global()` · `terra::cellSize()` · `terra::project()` ·
`terra::disagg()` · `terra::resample()` · `terra::not.na()` · `terra::datatype()` ·
`terra::describe()` · `read_stars()` · `str_subset()`

Verified new by `grep -rEho "\bNAME\(" modules/module_0 … modules/module_5`, which returns 0
for each.

### New arguments

`fact =`, `fun =`, `na.rm =` (in `terra::aggregate()`) · `unit =` (in `terra::cellSize()`) ·
`res =` (in `terra::project()`) · **`method =`** (in `terra::project()` / `terra::resample()`) —
**used in the main line at line 502 but defined only inside the `mysecret` box at line 518; see
M3** · `datatype =`, `gdal =`, `overwrite =` (in `terra::writeRaster()`) · `maxcell =`
(named at line 187, not demonstrated)

### New bolded terms, and their glossary status

**raster**, **grid**, **cells**, **resolution**, **raster layers**, **data cube** — all six are
present in the `glossary` table of `course_reference.sqlite` (`Raster`, `Grid`, `Cell`,
`Resolution` / `Resolution (rasters)`, `Raster layer`, `Data cube`), so the reference panel
generated by `find_lesson_references()` will resolve them. All 23 new functions are present in
the `functions` table as well, and all three datasets are present in `datasets` —
`lesson_metadata()` was run and returns correct, current text for `scbi_dem.tif`,
`scbi_canopy_cover.tif` and `dc_stack.tif`.
