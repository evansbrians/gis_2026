// Shared bootstrap for js-parsons drag-and-drop "Parsons problem" exercises
// embedded in course lesson pages.
//
// Depends on jQuery, jQuery UI (+ touch-punch), underscore.js, lis.js, and
// parsons.js all having already loaded -- see
// src/includes/parsons_includes.html, which loads this file last.
//
// Each problem's markup declares two empty containers -- "<id>-trash" and
// "<id>-sortable" -- plus a "<id>-check" button and a "<id>-feedback"
// message area (and, optionally, an "<id>-reset" button), then registers
// itself with:
//
//   window.parsonsProblems = window.parsonsProblems || [];
//   window.parsonsProblems.push({
//     id: "p-0-2-01",              // must match the container id prefix
//     code: "line one\nline two\nwrong line #distractor",
//     maxDistractors: 1            // how many "#distractor" lines to show
//   });
//
// Registration just pushes a plain object onto a global array, so it works
// no matter where the inline <script> that calls it sits relative to this
// file -- there's no dependency on this file, jQuery, or ParsonsWidget
// having already loaded at *registration* time, only by the time
// DOMContentLoaded fires, which is when everything below actually runs.

document.addEventListener("DOMContentLoaded", function () {
  var problems = window.parsonsProblems || [];

  problems.forEach(function (config) {
    if (typeof ParsonsWidget === "undefined") {
      // js-parsons failed to load (offline, blocked CDN, etc.) -- fail
      // quietly rather than throwing and breaking every other script on
      // the page (accordions, webexercises, etc.).
      return;
    }

    // Count the lines that belong in the answer (everything that is not a
    // "#distractor" line) so we can label and size the construction area.
    var solutionLineCount = config.code
      .split("\n")
      .filter(function (ln) {
        return ln.trim().length > 0 && ln.indexOf("#distractor") === -1;
      }).length;

    // These exercises are about line ORDER, not indentation, so we grade on
    // order only: strip any leading whitespace from every line (otherwise the
    // model solution would carry indent levels the student would also have to
    // reproduce) and disable indentation dragging. Opt back in per-problem
    // with canIndent: true if an exercise ever needs indentation graded.
    var gradeIndent = config.canIndent === true;
    var problemCode = gradeIndent
      ? config.code
      : config.code
          .split("\n")
          .map(function (ln) { return ln.replace(/^[ \t]+/, ""); })
          .join("\n");

    var widget = new ParsonsWidget({
      sortableId: config.id + "-sortable",
      trashId: config.id + "-trash",
      max_wrong_lines: config.maxDistractors || 0,
      can_indent: gradeIndent,
      trash_label: "Drag from here",
      solution_label:
        "Build your answer here (" + solutionLineCount + " lines)",
      feedback_cb: function (fb) {
        var fbDiv = document.getElementById(config.id + "-feedback");
        if (!fbDiv) return;
        // js-parsons passes the full grade result object here
        // ({ errors, log_errors, success }), NOT a bare errors array.
        var isCorrect = fb && (fb.success === true ||
          (fb.errors && fb.errors.length === 0));
        if (isCorrect) {
          fbDiv.textContent = "Correct -- nice work!";
          fbDiv.className = "parsons-feedback parsons-feedback-correct";
        } else {
          fbDiv.textContent =
            "Not quite yet. Check the order, and make sure you've left every distractor line in the trash.";
          fbDiv.className = "parsons-feedback parsons-feedback-incorrect";
        }
      }
    });

    widget.init(problemCode);
    widget.shuffleLines();

    // Tag the two columns so the stylesheet can distinguish the "source"
    // box from the "answer" box.
    var trashDiv = document.getElementById(config.id + "-trash");
    var sortableDiv = document.getElementById(config.id + "-sortable");
    var problemRoot = sortableDiv
      ? sortableDiv.closest(".parsons-problem")
      : null;
    if (trashDiv) {
      trashDiv.classList.add("parsons-source");
    }
    if (sortableDiv) {
      sortableDiv.classList.add("parsons-answer");
    }

    // Let every card wrap naturally, measure the tallest one, and then use
    // that height for every card and every answer bin. Computing the answer
    // height here also avoids unsupported CSS multiplication of a length by
    // the number of solution lines.
    var answerUl = document.getElementById("ul-" + config.id + "-sortable");
    var resizeFrame = null;
    function synchronizeCardAndBinHeights() {
      if (!problemRoot) return;

      problemRoot.classList.remove("parsons-sized");
      problemRoot.style.removeProperty("--parsons-card-height");

      var cards = problemRoot.querySelectorAll(".sortable-code li");
      cards.forEach(function (card) {
        card.style.removeProperty("height");
      });

      window.requestAnimationFrame(function () {
        var tallestCard = 0;
        cards.forEach(function (card) {
          tallestCard = Math.max(
            tallestCard,
            Math.ceil(card.getBoundingClientRect().height)
          );
        });
        if (tallestCard === 0) return;

        problemRoot.style.setProperty(
          "--parsons-card-height",
          tallestCard + "px"
        );
        problemRoot.classList.add("parsons-sized");

        var cardStyle = window.getComputedStyle(cards[0]);
        var slotHeight = tallestCard
          + parseFloat(cardStyle.marginTop)
          + parseFloat(cardStyle.marginBottom);
        problemRoot.style.setProperty("--slot-height", slotHeight + "px");

        if (answerUl) {
          var answerStyle = window.getComputedStyle(answerUl);
          var answerBorder = parseFloat(answerStyle.borderTopWidth)
            + parseFloat(answerStyle.borderBottomWidth);
          answerUl.style.setProperty(
            "--parsons-answer-height",
            (solutionLineCount * slotHeight + answerBorder) + "px"
          );
        }
      });
    }

    synchronizeCardAndBinHeights();
    window.addEventListener("resize", function () {
      if (resizeFrame !== null) {
        window.cancelAnimationFrame(resizeFrame);
      }
      resizeFrame = window.requestAnimationFrame(function () {
        synchronizeCardAndBinHeights();
        resizeFrame = null;
      });
    });

    var checkBtn = document.getElementById(config.id + "-check");
    if (checkBtn) {
      checkBtn.addEventListener("click", function () {
        widget.getFeedback();
      });
    }

    var resetBtn = document.getElementById(config.id + "-reset");
    if (resetBtn) {
      resetBtn.addEventListener("click", function () {
        widget.shuffleLines();
        synchronizeCardAndBinHeights();
        var fbDiv = document.getElementById(config.id + "-feedback");
        if (fbDiv) {
          fbDiv.textContent = "";
          fbDiv.className = "parsons-feedback";
        }
      });
    }
  });
});
