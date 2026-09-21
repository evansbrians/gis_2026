# Review: 6.1 Introduction to rasters with terra and stars

Reviewed: 8 Sep 2026 · Reviewer: Claude (fresh read, no prior knowledge of the draft)

**Materials read.** `modules/module_6/6.1_introduction_to_rasters.qmd`;
`brian_sandbox/module_review_protocol.md`; `brian_sandbox/lesson_voice_profile.md` (§0, §0.0 in
full; §2.60–§2.71; §7, §8.1–8.2, §9, §10 skimmed); the project doc `claude/lesson-scale-and-style.md`
(the attached-project copy — `brian_sandbox/claude_intructions/_lesson_scale_and_style.md` does
**not exist** at the path given, and the project doc was used in its place);
`src/reference/course_reference.sqlite` (`lessons`, `functions`, `function_usage`, `glossary`,
`datasets`).

**Prior context read.** 1.2, 2.3, 3.2, 3.4, 5.3, 6.0 module intro, 6.2, 6.3 (headings and setup),
6.4–6.7 (setup chunks and decision-tree figures only).

**What was executed.** All 39 runnable chunks were extracted and run in order from a clean session
(`Rscript`), plus five separate verification scripts. Chunks 1–4 (`include: false`, the
`lesson_metadata()` call, and the two `eval: false` skeletons at lines 92–107 and 734–742) were
read only. The Parsons problem at line 878 was unescaped and executed as an answer and again with
the distractor substituted. Behavioral claims were additionally checked against
`tools::Rd_db("terra")` for `project.Rd`, `aggregate.Rd`, `writeRaster.Rd` and
`SpatRaster-class.Rd`.

**Note on the protocol.** `module_review_protocol.md` is truncated between §4.6 and §4.9 — line 206
reads `ed by what it did.` and §4.7 and §4.8 are missing their headings and most of their content.
Code and style (5%) was therefore scored against the surviving fragment (`setwd()` never appears;
projects are assumed) plus the pipeline checks in §3–4 of `lesson-scale-and-style.md`. Anything
§4.7 covered that those do not is **not verified**.

---

## Typo corrections applied

- line 685: `**stars** is the package for that case` → `*stars* is the package for that case`
  (packages take italics; the lesson italicizes *stars* correctly in six other places).

That is the whole list. A spelling and punctuation sweep found no misspellings, no British
spellings, no doubled words, no dash pairs bracketing a clause, and no punctuation errors. The
mechanical quality of the draft is high.

---

## Scores

| Section | Weight | Score | Note |
|---|---|---|---|
| Scaffolding | 20% | 62% | three stale references to the deleted opener list; the whole grid-repair section is 6.3's subject; 6.0 promises drawing that the draft never teaches |
| Technical accuracy | 20% | 58% | two Critical false claims; four Major ones; but ~25 numeric and behavioral claims verified correct |
| Reproducibility and verification | 10% | 60% | every chunk runs and every printed number matches, but the figure does not exist and *stars* is not installed by the module |
| Clarity | 10% | 72% | a dangling demonstrative opens a section; one near-verbatim restatement; a worked example with no meaning |
| Voice | 10% | 55% | *refuses*, *gave*, *promise*, *pays* — the exact words §2.1 and §2.69 name; fourteen uses of *hold* |
| Depth | 10% | 62% | the cover-the-wrench test fails twice, and three take-home points come from wrench boxes |
| Exercises and assessment | 8% | 60% | Parsons runs and its distractor is real (good); one item is incoherent; two need wrench-box knowledge |
| Code and style compliance | 5% | 92% | pipeline ratios are excellent; zero replacement-function assignments; no forbidden base functions |
| Length | 5% | 25% | 3.8–4.1 hours against a 0.5–1.5 hour target |
| Structural conventions | 2% | 55% | clean-session ritual paraphrased; glossary panel will not contain the word "Raster" |
| **Overall** | **100%** | **61%** | |

**Hard stop.** Two Critical findings (lines 655 and 744) cap the overall score at 84. The weighted
mean is already below that, so the cap does not bind, but the rule applies: this lesson currently
teaches two things that are false.

**Band: below 70 — restructure.** The restructuring is mostly subtraction, not rewriting. Cut the
grid-repair material to 6.3, fix the two false claims, and repair the three references to the
opener list that Brian deleted, and the remaining lesson is close to good.

---

## Findings

### 4.1 Scaffolding — 20% · score 62%

**What is working, and should not change.** The `what does not match? → each answer has its own
function` frame at line 380 is the best structural idea in the draft. It gives the reader a
question to ask rather than four functions to remember, and the three `###` subsections beneath it
answer it in the order a reader would hit them. Every bold-italic cross-reference resolves against
the `lessons` table: ***1.2 Getting started***, ***4.3 Non-spatial joins***, ***3.4 The coordinate
reference system: Why it matters and how to use it*** and ***Preliminary Lesson 3: Values*** are
all exact `lesson_title` matches. That is four out of four, which is not the usual result.

---

**Major — lines 171–173.** A section opens on a demonstrative with no antecedent.

> `### Calculating where a cell is`
>
> `That is all a position calculation needs.`

The sentence immediately preceding it is the closing `:::` of the "Now you!" answer panel about
reading three files. *That* points at nothing. The reader also meets the phrase *a position
calculation* here for the first time, as a given. This is a residue of the consequence list that
§2.70/§2.71 records Brian deleting: the sentence used to follow the list and now follows a data
read. It also breaks §0.0 item 12 (bare demonstratives get a noun).

---

**Major — line 409.** A cross-reference to a list that no longer exists.

> `**A projection is a resampling**, and it is the clearest case of the third consequence in our
> list: move the grid and every value is recalculated.`

There is no list in this lesson, and no first or second consequence. The opener now runs
stake → structure → *Material covered will include*, exactly as §2.71 records. This sentence was
not swept when the list came out.

---

**Major — line 248.** The same residue, in a different form.

> `It is also where the constraints below come from, because the grid pays for its efficiency by
> refusing to store anything it can calculate.`

*The constraints below* names a set the reader was never given. §2.69's rule is also broken twice
in one clause — see Voice.

---

**Major — lines 358–541.** This section is 6.3's entire subject.

6.0's module overview says of 6.3: *"Two rasters can only be used together when they share a grid.
This tutorial covers `project()`, `aggregate()`, `disagg()` and `resample()`, and how to choose
between them."* Lines 358–541 of 6.1 teach `project()`, `aggregate()`, `disagg()` and `resample()`,
and how to choose between them. 6.3's decision tree (`matching_grids.svg`) and 6.1's proposed one
(`raster_model.svg`) carry the same branch in nearly the same words — compare the two `fig-alt`
strings. This is 184 lines, five code chunks, one wrench box, one checkpoint and one "Now you!" in
a lesson that is already over length. It is the natural cut.

---

**Major — the lesson never draws a raster.** 6.0's module overview says 6.1 covers *"how to draw
one with *tidyterra*"*. `grep -E "ggplot|geom_spat|tm_shape|plot\(|autoplot"` on the draft returns
nothing. A student finishes the first raster lesson of a GIS course without having seen a raster.
Either 6.0 is stale or the section is missing; the reader meets `dem`, `canopy` and `dc` only as
printed headers and numbers, which is also why the `canopy_per_meter` example (line 622) has
nothing to anchor it.

---

**Major — lines 80–124 against the rest of module 6.** Line 82 states:

> `*terra* supplies most of the functions in the rest of this module, and we will never write
> `library(terra)`.`

Every other lesson in the module writes it, in both its hidden setup chunk and the setup script
the student is told to build: 6.2 (lines 9, 90), 6.3 (9, 88), 6.4 (9, 91), 6.5 (9, 88),
6.6 (9, 91), 6.7 (10, 109). As the module stands, the claim about the rest of the module is false.
If the intent is that 6.2–6.7 will change, the sweep has not happened yet, and this is exactly the
"a thing described in several files" case §2.66 names.

---

**Major — movement 1 is missing.** §8.1 requires the model stated whole — a short enumerated list —
before any part is developed, and §2.71 records the previous list being deleted for good reasons
(each item was a claim the reader could not evaluate). Nothing replaced it. What remains is
*Material covered will include*, a table of contents, which §2.71 explicitly distinguishes from
scaffolding. The three dangling references above are the symptom: the lesson's architecture still
assumes a movement-1 list that was removed. The whole *is* available without any unevaluable
claims — line 28's *a raster is a grid of equally sized cells, each with a value; the location of a
cell is not part of the data* is the model, and it could carry the enumeration.

---

**Minor — lines 225–244 and 749–753.** `tempfile()` and `file.size()` are new. Neither appears in
any lesson 0.1–5.6 (checked by regex against every canonical `file_path` in the `lessons` table),
and neither is defined here. §4.1: no new function without a definition and an example.

---

**Minor — line 392.** `st_coordinates()` appears exactly once in the course before this, in 3.3,
inside a longer pipeline. `st_bbox()` and `st_as_sfc()` appear only in 5.5. The five-step pipeline
at lines 387–393 leans on all three at once with no comment on any of them. It is scaffolded, but
thinly, and this is the one pipeline in the lesson a reader is likeliest to copy without
understanding.

---

**Minor — line 384.** `We met `lonlat_to_utm()` in ***3.4 ...***` breaks §0.0 item 14: a
cross-reference names where a function is documented, not what the reader has done. The form is
*(see **3.4 The coordinate reference system: Why it matters and how to use it**)*.

---

### 4.3 Technical accuracy — 20% · score 58%

**What is working, and should not change.** A great deal was checked and held. Every arithmetic
and printed-output claim in the draft is correct: the 30× storage ratio (measured 29.78), the
~4 bytes per value (4.37), 5,850 cells, 152 missing blocks (78 + 75 − 1, exactly as the prose
says), 486,530 emptied cells, 75×78 and 750×780 against 745×778, ~9 m² and a ~3 m cell, 391
against 391.7271, a fifth of the size (0.178), and the `dc` canopy layer's range of 0 to 93.99999
used in the line-802 item. `cellSize()` was confirmed to vary across the raster (9.17349 to
9.176408), which is what the line-353 true/false item turns on. The `SpatRaster-class.Rd` quotation
at line 276 is verbatim and correctly attributed. The `aggregate()` rounding claim at line 426 is
confirmed by `aggregate.Rd`'s own worked example (100 columns, `fact=12`, 9 columns out).
`na.rm = TRUE` was confirmed to produce zero `NA` (line 438). The `[+] extents do not match` error
reproduces exactly. That is a high hit rate, and it is the part of the draft that most clearly
reflects the corrections in §2.65–§2.67.

---

**Critical — line 655.** A claim about the counterfactual path, and it is false.

> `` `filter()` has to come first. Dropping the `imp` layer before filtering on it leaves nothing to
> test, and the result is a valid raster of the wrong thing rather than an error. ``

Run:

```
dc %>% select(canopy) %>% filter(imp < 10)
Error in dplyr::filter(values, ...) :
i In argument: `imp < 10`.
Caused by error:
! object 'imp' not found
```

It is an error, and a clear one. The sentence teaches a reader to fear a silent wrong answer where
R will in fact stop them. This is §2.67's exact pattern: the lesson never runs the wrong order, so
the passing run never sees the claim. *Run the code without the step before writing the sentence
that says what happens without it.*

---

**Critical — line 744.**

> `The default is `FLT4S`, four-byte floating point, and it keeps every value exactly.`

`FLT4S` is the default — confirmed, `datatype(rast(default_file))` returns `"FLT4S"` for an
in-memory double raster. But it does not keep every value exactly. Written and read back:

| in | out |
|---|---|
| 1.123456789012345 | 1.1234568357467651 |
| 3.14159265358979 | 3.1415927410125732 |
| 1e-40 | 9.9999461011147596e-41 |

The claim happens to hold for `dem` because `dem` is itself `FLT4S` on disk, which is what hides
it. In a section whose heading is *"the values that survive it"*, a false claim about which values
survive the default is the worst place for one. The true statement is that `FLT4S` keeps about
seven significant digits, and that `FLT8S` is the type that keeps an R double.

---

**Major — line 260.**

> `**`source`** is the fifth line and the one people skip.`

Count the printed summary the reader is looking at, three lines above:

```
class       : SpatRaster      <- 1
dimensions  : 745, 778, 1     <- 2
resolution  : 3.08642e-05...  <- 3
extent      : -78.17401...    <- 4
coord. ref. : lon/lat NAD83   <- 5
source      : scbi_dem.tif    <- 6
```

It is the sixth. This is §2.66's *"the refutation was already on the page"* — a claim about printed
output, written directly beneath that output. Two related notes: the label is `source` only for a
single-source raster; a multi-layer or in-memory raster prints `source(s)`, which the lesson's own
chunk at line 604 shows, so a reader told to look for a line called `source` will be looking for
the wrong string half the time. And *"the one people skip"* is a claim about readers, not about
the material (§2.11).

---

**Major — line 286.**

> `An operation that has to build a new grid has no file to point at, so its result lands in
> memory:`

The mechanism is wrong and the conclusion is not general. terra creates a file when it needs one:

```
terraOptions(todisk = TRUE)
dem %>% terra::aggregate(fact = 50) %>% terra::inMemory()
[1] FALSE
source : spat_GUlPQvx18WucHRM_2063.tif
```

6.0's own module intro already says so: *"terra will attempt to hold raster values in your
computer's memory, and will write them to a temporary file on your hard drive when it cannot."*
That makes this an internal contradiction as well as a wrong mechanism. It also weakens the
diagnostic at line 292 and Exercise 2 at line 850: on a large raster the `source` line reads
neither `memory` nor the reader's own filename but a `spat_*.tif` in the temp directory, which is
the case the exercise's scenario ("a script that ran yesterday now fills the machine's memory") is
most likely to produce.

---

**Major — line 498.**

> `Land cover class 21 is roads and class 41 is forest, and the average of the two is class 31,
> which is barren ground that neither cell contained.`

This is true of the Warren County, VA key the course ships as `lc_key_warren_county_va.csv`
(21 = *Roads*, 41 = *Forest*, 31 = *Harvested Forest Barren*) and 6.2 uses. It is not true of the
scheme the reader is holding in this lesson. The only land-cover layer in 6.1 is `dc$nlcd`, whose
values are NLCD codes (`freq()` returns 11, 21, 22, 23, 24, 31, 41, 42, 43, 52, 71, 81, 82, 90,
95). Under NLCD, **21 is Developed, Open Space** — roads are 22, 23 and 24. 41 is Deciduous Forest
and 31 is Barren Land, so the rest of the sentence survives. The sentence is also duplicated in
6.2 line 28 and 6.3 line 210; §2.66's rule about a claim living in three files applies. Suggested
direction: name the scheme, or move the example to a class pair that means the same thing in both.

---

**Major — lines 791–797.**

> `Compression is the saving that costs nothing:` … `Smaller than the default, with every value
> intact, because DEFLATE is lossless.`

The measured claim is true — 1,935,732 against 2,369,174, so DEFLATE is 18% smaller. The model the
passage builds is not. terra's `writeRaster.Rd` states: *"GeoTiff files are, by default, written
with LZW compression. If you do not want compression, use `gdal="COMPRESS=NONE"`."* Confirmed on
the file the lesson writes:

```
Image Structure Metadata:
  COMPRESSION=LZW
```

and `COMPRESS=NONE` gives 2,324,144 — *smaller* than the default, because LZW achieves nothing on
float elevation data and adds overhead. So the reader is taught "the default is uncompressed; add
DEFLATE to compress it" when the truth is "the default is LZW; DEFLATE compresses this kind of data
better." A reader who carries the wrong model to a categorical raster, where LZW does very well,
will draw the wrong conclusion.

---

**Minor — line 496.**

> `` `st_transform()` moves a vector's coordinates exactly — the geometry is the data, and it can be
> recomputed without loss.` ``

A 4269 → 32617 → 4269 round trip on a point returned bit-identical coordinates, so the claim
survives the test I could run. **Unverified** for a transformation that crosses datums, where the
shift is an empirical approximation (a grid shift or a Helmert transform) rather than a closed-form
projection; *exactly* and *without loss* are stronger than the mechanism supports there. The point
the box is actually making — that a vector is transformed vertex by vertex while a raster has to be
re-gridded, so only one of the two invents values — is true and does not need *exactly*.

---

**Minor — line 378.** *"a resolution nine times coarser"* — the ratio is 0.0002899097 / 3.08642e-05
= 9.39. *"an extent that differs in the fourth decimal place"* — three of the four bounds do;
`ymin` differs at the fifth (38.87901 against 38.879). Both are close enough to be honest and both
are looser than the printed output beneath them.

---

**Minor — lines 409, 498 and 832 together.** The near-versus-bilinear advice never mentions that
`project.Rd` makes the choice automatically: *"'near' … is used by default if the first layer of
'x' is categorical"*, *"'bilinear' … is the default if the first layer of 'x' is numeric"*. For a
raster carrying a category table, terra already does the right thing. That matters because
Exercise 4 asks what is wrong with `method = "bilinear"` on a land cover raster, and its second
option — *"Nothing: bilinear is the default and the default is correct"* — is closer to true than
the item intends for a categorical `SpatRaster`. (`dc$nlcd` is not categorical — `is.factor()`
returns `FALSE` for all four layers — so the item is answerable for this data, but the general
statement it rests on is under-specified.)

---

### 4.4 Reproducibility and verification — 10% · score 60%

**What is working, and should not change.** All 39 runnable chunks execute in order from a clean
session with exactly one error, the deliberate one at line 367. Every object, column and layer name
referenced exists at the point it is used. Every number quoted in prose is derived from a chunk
that is shown. The two "Now you!" answer panels that produce output both reproduce the numbers the
prose then discusses (42,376 and the four layer means). This is a clean run, and it is what §2.65
asked for.

---

**Major — line 815.** The figure does not exist.

`src/images/decision_trees/raster_model.svg` is not in the repository. That directory holds
`reading_a_raster.svg` — evidently this lesson's earlier tree, now unreferenced by any lesson — plus
`matching_grids.svg`, `categorical_rasters.svg`, `rasters_and_vectors.svg`, `map_algebra.svg`,
`terrain.svg` and `shiny_app.svg`, one for each of 6.2–6.7. A rename reached the `.qmd` and did not
reach the drawing. 6.1 is the only module 6 lesson whose SVG is missing.

---

**Major — line 817.** `{{< include ../../src/includes/decision_tree_pdfs/raster_model.qmd >}}`
does not exist either. `src/includes/decision_tree_pdfs/` contains only `ggplot.qmd`,
`reshaping.qmd` and `tidying.qmd`. This one is course-wide — every module 5 and 6 lesson includes a
file that is not there — so it is a build-state finding rather than a defect of this draft, but the
lesson will not render until it is resolved.

---

**Major — *stars* is never installed.** 6.0's *Getting started* runs
`install.packages(c("ggnewscale", "rayshader", "shiny", "terra", "tidyterra"))`. The word *stars*
does not appear anywhere in 6.0. Lines 10 and 100 of this draft attach it and line 689 calls
`read_stars()`. A student who followed the module intro will fail at `library(stars)`.

---

**Major — the metadata panel and the exercise disagree about units.** The `datasets` row for
`dc_stack.tif`, which `lesson_metadata()` prints into the accordion the reader opens at line 46,
says *"canopy (proportion of canopy cover), imp (proportion of impervious surface)"*. The values are
percentages: `imp` runs 0 to 100, `canopy` 0 to 93.99999. The "Now you!" at line 630 then asks for
*"impervious surface … below ten percent"* and the answer writes `imp < 10`. A reader who trusted
the metadata panel would write `imp < 0.1` and get an empty raster. The same row's `scbi_dem.tif`
`description` says *10 m resolution* while its `metadata_description` says *about three meters*;
the second is right (measured 3.03 m).

---

**Minor — line 737.** `terra::writeRaster("data/processed/campus.tif")` is `eval: false`, so nothing
verifies that `data/processed/` exists in a student's project. Prior lessons that write there may
already establish it; **not verified** against the module 6 file-structure instructions.

---

**Minor — line 217.** `terra::ncell(small)` prints 5,850 and no sentence anywhere reads that number
back. §2.2 of the scale-and-style doc: *"A chunk whose output nobody points at is a chunk the reader
skims."*

---

### 4.5 Depth — 10% · score 62%

**What is working, and should not change.** The wrench box at lines 489–499 is the best writing in
the draft. *"Each of the repairs above calculates new values from old ones, and each loses a
little"* gives an advanced reader a reason to order an analysis a particular way, and it is exactly
the kind of enhanced understanding §0 asks for. The box at 575–583 is nearly as good, and its
second half — that `filter()` is not how you make a raster smaller — answers a question a student
will actually have.

---

**Major — three take-home points come from behind the wrench.**

- line 839: `Settle a package conflict once with `conflicts_prefer()` rather than on every call with
  `::`.` — *conflicted* and `conflicts_prefer()` appear only in the `mysecret` box at lines 111–125.
  Worse, the take-home **reverses the lesson's own recommendation**: line 124 says *"This course
  takes the first"* (the `terra::` prefix), and the main line spends four paragraphs on why. A
  reader who reads only the take-home points learns the opposite of what the lesson taught.
- line 833: `Move the vector rather than the raster where you have the choice` — box only (line 496).
- line 832: `` `method = "near"` rather than `"bilinear"` whenever the values are classes `` — box
  only (line 498).

§9's ruling is that nothing behind the wrench is required knowledge. A take-home point is the
definition of required knowledge.

---

**Major — the *stars* section is main line and probably should not be.** Lines 672–716 introduce a
second package, a second object model, a second print format and two new bolded terms, for material
6.0 does not list under 6.1 and no later lesson uses (`read_stars` appears in no other module 6
lesson). It is genuinely interesting and it is well written. §4.5's rule is that
interesting-but-adjacent material is in a box, stated completely and in one place, or cut. As main
line in an already over-long lesson, it is the clearest candidate for the box.

---

**Minor — line 622.** `canopy_per_meter = canopy / elevation` is percent canopy divided by meters
above sea level. It is not a quantity anyone would want, and the prose does not claim it is; but a
reader building a mental model of `mutate()` on layers is being shown an operation whose result
means nothing, where 2.3's parallel example (`mass_index = mass / mean_mass`) means something. The
mechanism the sentence at 625 wants — *"the third was calculated from the two above it without
using a coordinate"* — would survive an example that also means something.

---

### 4.6 Exercises and assessment — 8% · score 60%

**What is working, and should not change.** The Parsons problem was extracted, unescaped and run.
The answer executes as written and returns the two-layer UTM raster the prompt asks for. The
distractor is a real distractor: substituting `method = "near"` for `"bilinear"` changes 521,842
cells. After §2.65 and §2.66 recorded three defective Parsons problems in module 6 alone, this one
passes both tests. Several checkpoint items are also well made — the line-663 `ncell()` item and
the line-802 `INT1U` item both test a model the reader has to have built rather than a fact they
can look up, and the line-802 item's numbers are the real range of the real layer.

---

**Major — the cover-the-wrench test fails twice.**

- **Exercise 4, line 858–860.** *"A land cover raster is projected with `method = "bilinear"`. What
  is wrong with the result?"* The answer and the two most plausible distractors all turn on the
  near-versus-bilinear rule, which exists in this lesson only inside the wrench box at line 498. A
  beginner who skipped it cannot eliminate anything.
- **Exercise 5, line 862.** *"One line supplies the resampling method that a class needs rather than
  the one a quantity needs."* Same knowledge, same box, and here it is the whole task.

§9: *"A wrong option a beginner cannot rule out costs them the question exactly as surely as a
right option they cannot reach."*

---

**Major — line 725.** The true/false item is incoherent.

> `True or false: a monthly time series of one grid is better held as four layers than as a fourth
> dimension.`

*Monthly* and *four* do not agree, and a time series of one grid is a **third** dimension — x, y,
time — not a fourth. The lesson's own example at line 706 is *"One attribute on **three**
dimensions"*. A reader who understood the section will be checking their arithmetic rather than
answering.

---

**Minor — line 848.** The distractor *"Rasters have no columns to use as a key"* is undercut by the
lesson itself. Line 609 says *"the verbs address them the way they address columns"* and lines
612–623 select and mutate layers exactly as columns. A reader who took that seriously has reason to
think this option is true.

---

**Minor — the Parsons prompt and its answer disagree about a name.** The prompt asks for *"a
two-layer raster of elevation and canopy cover"*; the code produces layers named `Layer_1` and
`canopy`. Small, but §2.65's *"read the prompt against the code beneath it"* is the rule that
catches exactly this.

---

**Minor — no checkpoint for four new functions.** `xyFromCell()`, `cellFromXY()`,
`terra::as.points()` and `not.na()` are introduced and never assessed. §4.6 asks for a checkpoint
for every new function while its data is in scope. Coverage is otherwise good.

---

**Minor — the volume.** Five "Now you!" challenges, five two-item checkpoints and a six-item
exercise block is 17 assessment items and 5 challenges. The measured targets are 3–5 MCQ, 2–3
true/false and 5–8 `now_you` blocks. This is roughly triple the quiz target — see Length.

---

### 4.2 Clarity — 10% · score 72%

**What is working, and should not change.** The lesson's central explanations are unusually clear.
Lines 545–555 — *"a row can be dropped because nothing else depends on where it sat. A raster is a
rectangle indexed by row and column, and a rectangle has no way to hold a gap"* — is the sentence a
reader will remember, and it is Brian's own from §2.70. Line 342, *"The number in `resolution` was
never wrong; it was answering a different question than the one people ask of it"*, does real work
in one sentence. Lines 694–706 read the `stars` print back element by element and then name the two
things it shows that the `SpatRaster` print did not, which is §2.2 of the scale doc done properly.

---

**Major — line 173.** The dangling *That*, reported under Scaffolding, is also the clearest clarity
failure in the draft: a reader who starts the section cannot parse its first sentence.

---

**Major — lines 206 and 220.** A near-verbatim restatement two chunks apart.

> line 206: `… and write it out both ways: once as a raster, and once as one point per cell.`
>
> line 220: `Write those values both ways, once as a raster and once as one point per cell:`

§0.0 item 8. One of the two is the sentence; the other is a signpost that delivers what the reader
has already been told.

---

**Minor — line 685.** The definition uses a colon-splice, which §0.0 item 10 rules out.

> `It treats a raster as one instance of a **data cube**: an array with named dimensions, of which
> x and y are two, and time or band or depth can be more.`

The gerund form the rule asks for is available: *A data cube is an array with named dimensions, of
which x and y are two and time, band or depth may be others.*

---

**Minor — lines 358 and 543.** Two headings still carry causal connectives.

> `## Because there is no stored position, there is no key`
>
> `## Because the grid stays rectangular, filter() empties cells rather than removing them`

Both claims are ones §2.70 tested and accepted, so these are not the unchecked kind. But §2.70's
closing note is *"A causal connective in a heading is a claim"*, and these two are the last of the
seven that structure survived. They are also the two longest headings in the lesson.

---

**Minor — line 292.** `it is the first thing to check when a script that ran yesterday will not run
today` and Exercise 2's stem, *"A script that ran yesterday now fills the machine's memory"*, are
the same sentence twice. That is fine as reinforcement; what is not is that the exercise's scenario
is the one case where the advice is incomplete (see the line-286 finding).

---

### 4.7 Voice — 10% · score 55%

Scored against `lesson_voice_profile.md`, §0 and §0.0 in full, §2.68–§2.71, and §2 skimmed.

**What is working, and should not change.** The opener at lines 26–28 is exactly the text §2.68
records Brian accepting, unchanged, and the paragraph beneath it is the one §2.69 says finally
passed — copula, agentless passive, no data noun acting. The stake comes first. There is no
invented anecdote, no place the reader is asked to imagine standing, no *not X but Y*, no matched
dash pair, no inflated quantifier, and no sentence about the lesson rather than the material in the
first forty lines. The `mysecret` at 489 and the take-home list are written in the register the
profile asks for. The lesson also gets the *feature* collision right: §2.71 records the sentence
that produced it being cut, and it is gone.

---

**Major — §2.1's own forbidden words, twice, verbatim.**

- line 362: `*terra* refuses when the arrays do not line up`. §2.1's list is *give, hand, offer,
  want, refuse, happily*. And *terra* is a package, not even a function, so the §2.1 exemption for
  functions does not reach it.
- line 706: `` where `rast()` gave four layers on two ``. *Give* is the first word on the list.

---

**Major — §2.69's sweep, run on the current draft.** The rule is that a raster, a file, a grid, a
cell, a layer, a value, a table or an object is never the subject of an action verb. Current hits:

| line | text |
|---|---|
| 248 | `the grid **pays** for its efficiency by **refusing** to store anything it can calculate` |
| 292 | `a raster that is still a **promise**` |
| 587 | `A rigid grid also **makes** the stacking free` |
| 674 | `The District file … **holds** four layers, and *terra* calls them layers because a grid **has no other name** for them` |
| 694 | `The print **carries** the attributes, which are the variables the cube **holds**` |
| 698 | `A `SpatRaster` **stores** the same orientation and does not print it` |
| 378 | `A join would have **coped** with all three` |
| 191 | `` `xyFromCell()` **looked nothing up** `` … `` a file it had never opened `` |
| 202 | `There is no geometry column because there is nothing to **put in it**` |
| 580 | `` `ncell()` **has not moved** `` |

Line 292 is the one to note particularly: §2.69 records *"a file is a promise about the values"* as
one of the eleven hits Brian's own sweep returned on this lesson. The metaphor survived into the
current draft in the sentence directly beneath the `inMemory()` chunk. Line 248 breaks the rule
twice in one clause and uses §2.1's *refuse* while doing it.

*Hold* is the highest-frequency offender — fourteen occurrences, at lines 84, 88, 265, 496, 547,
555, 565, 630, 649, 674, 683, 694, 725, 802 — and §2.69 names it explicitly. Two of them are inside
assessment items (265, 802), which §2.69 also says the sweep must reach. Note the exception: line
276 quotes terra's documentation and must keep its wording.

---

**Minor — idiom (§0.3, §0.0 item 4).** Each of these has a word not doing its literal job:

| line | phrase |
|---|---|
| 398 | `With the code **in hand**` |
| 426 | `the last row and column of blocks **hang over the edge**` |
| 440 | `why the round trip **does not come home**` |
| 791 | `Compression is the **saving that costs nothing**` |
| 587 | `makes the stacking **free**` |
| 835 | `a count of cells and a count of values **part company**` |

---

**Minor — §5a, counting.** `the four layers of dc` (311), `Four different measurements` (681),
`four months` (683), `the third consequence` (409), `all three` (378). The `dc` layer count is
printed by `names()` on the reader's screen at line 677, so the reader can count it.

---

**Minor — §9, `mysecret` titles.** Every `mysecret` title is a complete sentence. Two of the four
are noun phrases: `The alternative, if you would rather attach it` (112) and `Which package, and
why` (709). The other two are correct.

---

**Minor — line 260.** `the one people skip` is a claim about readers, and line 797's `this is the
one I set on every raster I write` is correct use of *I* for practice (§1) — the contrast is worth
noting because the draft otherwise handles the we/I split well.

---

**Observation, not a finding.** Bold is used for sentence-level emphasis 17 times (of 41 bolds).
Comparable lessons: 3.4 has 10 of 42, 2.3 has 8 of 24, 5.3 has 4 of 19, 3.2 has 4 of 16. So the
device is Brian's, and this draft uses it at the top of his range. It interacts with a real defect —
see Structural conventions.

---

### 4.8 Code and style compliance — 5% · score 92%

Scored against `lesson-scale-and-style.md` §3–4 and the surviving fragment of the protocol's §4.8;
§4.7 and most of §4.8 are missing from `module_review_protocol.md`, so anything they added is **not
verified**.

**What is working, and should not change.** This is the strongest section of the draft, and it is
precisely where the 8 Sep instruction was aimed.

```
grep -cE "^[a-z_.]+\([a-z_.]+\) *<-"  →  0     (target 0)
grep -c "%>%" ; grep -c " <- *$"      →  55 / 8 = 6.9   (target >= 3)
grep -nE "\b(head|paste0|paste|round|as.data.frame)\(" →  empty
grep -n setwd                          →  empty
```

Against the measured baselines — Brian 3.73 pipes per assignment, the earlier module 6 drafts 1.64 —
this draft is at 6.9. `rename(elevation = 1, canopy = 2)` is used where `names(x) <- ` would have
been, exactly as §3.2 of the style doc prescribes. `str_c()` rather than `paste0()`. The `terra::`
prefix is applied consistently and never with a bare call. Answer panels carry step comments inside
the chain, introduced with a colon (lines 639–651), which §3.3 asks for and the earlier drafts
lacked.

**Minor.** `is.na()` and `dim()` are called bare in pipes (lines 434, 450, 561). Neither is on the
substitution table and both read naturally here; noting only because §3.2's spirit is that a base-R
call in a chain wants a reason.

---

### 4.9 Length — 5% · score 25%

**Method.** Prose words counted after stripping fenced R chunks and the `<script>` block (5,430
words, of which roughly 250 are the `fig-alt` string at line 815, which a sighted reader does not
read — call it 5,180 of teaching prose, and use 5,430 to stay conservative in the lesson's favour…
in fact using the smaller figure changes the total by two minutes, so the choice does not matter).
Chunks counted as reader-visible: 44 total, less two `include: false` and one `echo: false`
metadata chunk = 41, of which 39 are executable. New functions counted as those introduced here and
found in no canonical lesson 0.1–5.6: `rast`, `xyFromCell`, `cellFromXY`, `res`, `aggregate`,
`ncell`, `writeRaster`, `as.points`, `inMemory`, `global`, `cellSize`, `project`, `disagg`,
`resample`, `not.na`, `read_stars`, `tempfile`, `file.size`, and `c()` in its stacking sense = 19.

| Element | Count | Rate | Minutes |
|---|---|---|---|
| Prose | 5,430 words | 130 w/min | 41.8 |
| Code chunk to run and interpret | 39 | 1.5 min | 58.5 |
| New function introduced | 19 | 3 min | 57.0 |
| Under-the-hood box | 4 | 2 min | 8.0 |
| "Now you!" challenge | 4 | 8–12 min | 32–48 |
| Parsons problem | 1 | 8 min | 8.0 |
| Quiz / checkpoint item | 15 | 1.5 min | 22.5 |
| **Total** | | | **227.8 – 243.8 min = 3.8 – 4.1 h** |

**Calibration.** The same method applied to 2.3, a lesson that has been through Brian's review and
that he is satisfied with, returns about 154 minutes (2.6 h) — so the protocol's rate table runs
over the stated 1.5 h ceiling even for a known-good lesson. Taking 2.3 as the reference, this draft
is **1.5–1.6× the length of the longest lesson the course currently ships**, and about 2.6× the top
of the stated window.

**Against the measured targets** in `lesson-scale-and-style.md` §1:

| | Target | This draft |
|---|---|---|
| Prose words | 3,500–4,500 | **5,430** |
| Code chunks | 30–45 | 44 ✓ |
| `now_you` blocks | 5–8 | 11 (4 challenges + 5 checkpoints + exercises) |
| Worked answer panels | ≥ 3 | 4 ✓ |
| `###` subsections | 5–8 | 8 ✓ |
| MCQ items | 3–5 | **10** |
| True/false items | 2–3 | **7** |

The correction of the 8 Sep instruction has overshot on prose and on assessment volume while
landing exactly on chunks, answer panels and subsections.

**The fix is to split, not to cut.** Lines 358–541 — the grid-repair section, roughly 184 lines,
five chunks, one wrench box, one checkpoint and one challenge — are 6.3's subject and 6.3 exists.
Moving that section removes about 60 minutes and takes the prose to roughly 4,200 words, inside the
target. Moving the *stars* section into a box (or to 7.1, where `stars` would sit naturally beside
the advanced raster material) removes another 25. What remains is a 2.5–3 hour lesson, which is
still above the stated window but in line with 2.3 and 3.2.

---

### 4.10 Structural conventions — 2% · score 55%

**What is working, and should not change.** The section order is exactly the convention:
`Data for this lesson` → `Set up your session` (with the read inside it) → concept sections →
`Putting it all together` → `Take-home points` → `Exercises` → `Reference`. Take-home points come
before the exercises. Headers are sentence case, `##` for major sections and `###` for sub-topics.
File names are code spans, not `.mono` (§2.61). Internal cross-references are bold-italic and not
links. The `Check your understanding` callout markup matches every other lesson in the course
character for character. A decision-tree section is present, as the module's other lessons have one.

---

**Major — the reference panel will not contain the word "Raster".** `find_lesson_references()` was
run on the draft. Its glossary output is:

```
"Code section"  "Global environment"  "Session history"  "Workspace pane"  "Attributes"  "Dimensions"
```

Four of those are the setup ritual and two are from the *stars* section. The `glossary` table holds
**Raster**, **Raster stack**, **Resolution (rasters)**, **Extent**, **Layers** and **Categorical
raster**, and none of them reaches the panel, because `find_lesson_references()` matches bolded
terms and this lesson never bolds *raster*, *cell*, *layer* or *grid*. `**`resolution`**` at line
258 misses because the glossary stores *Resolution (rasters)*, which is not one of its aliases.
**data cube** is bolded and has no glossary row at all, so the lesson's one new term produces
nothing either. §10: *"before rewording any sentence containing a bolded term, grep the lesson for
another bolded instance"* — the mirror of that rule applies here, which is that the terms carrying
the panel have to be bolded somewhere.

The function panel is similarly thin: `xyFromCell`, `cellFromXY`, `not.na`, `writeRaster`,
`as.points`, `read_stars`, `tempfile` and `file.size` are absent from the `functions` table, so
eight of the nineteen new functions will not appear in the reference the lesson ends with.

---

**Major — the clean-session ritual is paraphrased.** Every comparable lesson (2.3, 3.4, 5.3, 6.2,
6.3) runs five numbered steps and then the line *"At this point, your script should look something
like:"*. This draft stops at step 4, drops step 5 entirely (the step that names which packages to
attach and tells the reader to load the source script), inserts a 45-line `### We do not attach
*terra*` section between the numbered list and the chunk, and replaces the standard lead-in with
*"The setup section therefore attaches everything except the package we use most:"*. §4.10: *"The
clean-session ritual is verbatim boilerplate and is not paraphrased."* The *terra* discussion is
good material; it belongs before or after the ritual rather than inside it.

---

**Minor — the objectives list uses the older form.** 6.1 has `Material covered will include:` with
noun-phrase topics. 2.3, 3.4, 5.3 and 6.2 — including this lesson's own module sibling — use
`In completing this lesson, you will learn how to:` with verb-led objectives. 3.2 still uses the
older form, so it is drift rather than an error, but 6.1 and 6.2 disagreeing inside one module is
the visible cost.

---

**Minor — the lesson title disagrees with the course record.** The YAML says *"6.1 Introduction to
rasters with terra and stars"*. The `lessons` table and 6.0's module overview both say *"6.1
Introduction to raster data"*. Any other lesson cross-referencing 6.1 in bold-italic will use the
database title.

---

## Function inventory (appendix)

Built from the `functions` / `function_usage` tables and verified by regex against every canonical
lesson file for modules 0–5.

### Already introduced, correctly treated as known

| Function | Introduced in |
|---|---|
| `library()` | 0.2 Preliminary Lesson 2: Environment & Functions |
| `c()` | 0.2 Preliminary Lesson 2: Environment & Functions |
| `as.integer()` | 0.3 Preliminary Lesson 3: Values *(cited at line 789)* |
| `names()` | 0.4 Preliminary Lesson 4: Objects |
| `dim()` | 0.4 Preliminary Lesson 4: Objects |
| `is.na()` | 2.1 Introduction to subsetting and extraction |
| `filter()` | 2.1 Introduction to subsetting and extraction |
| `select()` | 2.1 Introduction to subsetting and extraction |
| `rename()` | 1.5 Assignments |
| `mutate()` | 2.2 Introduction to mutation |
| `str_c()` | 1.5 Assignments |
| `%>%` | 1.4 Importing, exploring, and exporting data |
| `source()` | 3.2 Introduction to spatial vector data |
| `st_as_sf()` | 3.2 Introduction to spatial vector data |
| `st_transform()` | 3.2 Introduction to spatial vector data *(named at line 496)* |
| `st_coordinates()` | 3.3 Constructing and converting simple features — **one use, thin** |
| `lonlat_to_utm()` | 3.4 The coordinate reference system *(cited at line 384)* |
| `st_centroid()` | 3.6 Geometric operations with sf |
| `st_write()` | 4.4 Iteration with purrr |
| `st_bbox()` | 5.5 Cartography II — **one lesson, thin** |
| `st_as_sfc()` | 5.5 Cartography II — **one lesson, thin** |

### New in this lesson

| Function | Line | Defined? | Example? | Checkpoint? |
|---|---|---|---|---|
| `terra::rast()` | 135 | yes | yes | yes (ex. 2 indirectly) |
| `terra::xyFromCell()` | 176 | yes | yes | **no** |
| `terra::cellFromXY()` | 196 | yes | yes | **no** |
| `terra::res()` | 188 | yes | yes | yes (line 349) |
| `terra::aggregate()` | 211 | yes (again at 413) | yes | yes (line 464) |
| `terra::ncell()` | 217 | **no** — used before the term *cell count* is named | yes | yes (line 663) |
| `terra::writeRaster()` | 230 | yes (fully at 732) | yes | yes (line 802) |
| `terra::as.points()` | 233 | **no** | yes | **no** |
| `terra::inMemory()` | 279 | yes | yes | yes (ex. 2) |
| `terra::global()` | 294 | yes | yes | yes (Now you!, 311) |
| `terra::cellSize()` | 334 | yes | yes | yes (line 353) |
| `terra::project()` | 384 | yes | yes | yes (Now you!, 504) |
| `terra::disagg()` | 449 | yes | yes | yes (line 468) |
| `terra::resample()` | 479 | yes | yes | partial |
| `terra::not.na()` | 565 | inline only | yes | **no** |
| `c()` for stacking | 587 | yes | yes | yes (line 667) |
| `stars::read_stars()` | 689 | yes | yes | yes (line 721) |
| `tempfile()` | 225 | **no** | yes | **no** |
| `file.size()` | 241 | **no** | yes | **no** |

### New arguments

`fact = `, `fun = `, `na.rm = ` (aggregate, 211); `unit = ` (cellSize, 336); `res = ` (project,
519); `method = ` (resample/project, 481); `datatype = ` (writeRaster, 761); `gdal = `
(writeRaster, 768); `overwrite = ` (writeRaster, 230); `quiet = ` (st_write, 235).

### New bolded terms

**data cube** (685) — no glossary row. **attributes** (694) and **dimensions** (694) — both resolve.
**core tidyverse** (109) — the glossary stores *Core tidyverse package*, which the alias rule does
not reach. The lesson's own subject, **raster**, is never bolded and therefore never reaches the
reference panel.
