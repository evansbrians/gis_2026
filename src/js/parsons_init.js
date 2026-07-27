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

    var widget = new ParsonsWidget({
      sortableId: config.id + "-sortable",
      trashId: config.id + "-trash",
      max_wrong_lines: config.maxDistractors || 0,
      can_indent: config.canIndent !== false,
      feedback_cb: function (errors) {
        var fbDiv = document.getElementById(config.id + "-feedback");
        if (!fbDiv) return;
        if (errors.length === 0) {
          fbDiv.textContent = "Correct -- nice work!";
          fbDiv.className = "parsons-feedback parsons-feedback-correct";
        } else {
          fbDiv.textContent =
            "Not quite yet. Check the order, and make sure you've left every distractor line in the trash.";
          fbDiv.className = "parsons-feedback parsons-feedback-incorrect";
        }
      }
    });

    widget.init(config.code);
    widget.shuffleLines();

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
        var fbDiv = document.getElementById(config.id + "-feedback");
        if (fbDiv) {
          fbDiv.textContent = "";
          fbDiv.className = "parsons-feedback";
        }
      });
    }
  });
});
