// Shared bootstrap for js-parsons drag-and-drop "Parsons problem" exercises
// embedded in course lesson pages. Cards can be dragged with a mouse or moved
// with the keyboard -- see the keyboard section below -- and no controls are
// drawn on the cards, so the code text keeps the full width of its capsule.
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
// A problem may also set:
//
//   unordered: true               // grade membership, not order
//   answerNoun: "functions"       // what the answer box counts, for its label
//
// "unordered" is for categorization exercises -- the student drags the cards
// that belong to a category into the answer and leaves the rest behind, and
// the order they land in carries no meaning. See SetBasedGrader below.
//
// Registration just pushes a plain object onto a global array, so it works
// no matter where the inline <script> that calls it sits relative to this
// file -- there's no dependency on this file, jQuery, or ParsonsWidget
// having already loaded at *registration* time, only by the time
// DOMContentLoaded fires, which is when everything below actually runs.

// Grader for categorization problems (unordered: true). js-parsons' own
// LineBasedGrader grades position, which would ask a student to reproduce an
// order that carries no meaning; this one grades membership. A card that does
// not belong in the answer is highlighted, and a short answer reports as
// missing lines -- the same two failure modes, judged as a set.
function SetBasedGrader(parson) {
  this.parson = parson;
}

SetBasedGrader.prototype.grade = function (elementId) {
  var parson = this.parson;
  var elemId = elementId || parson.options.sortableId;
  var studentLines = parson.getModifiedCode("#ul-" + elemId);

  // How many times each line is expected in the answer.
  var remaining = {};
  parson.model_solution.forEach(function (line) {
    remaining[line.code] = (remaining[line.code] || 0) + 1;
  });

  var errors = [];
  var logErrors = [];
  var incorrectLines = [];

  studentLines.forEach(function (line) {
    if (remaining[line.code] > 0) {
      remaining[line.code] -= 1;
    } else {
      line.markIncorrectPosition();
      incorrectLines.push(line.orig);
    }
  });

  var missing = Object.keys(remaining).reduce(function (total, code) {
    return total + remaining[code];
  }, 0);

  if (incorrectLines.length > 0) {
    errors.push("Highlighted items do not belong in the answer.");
    logErrors.push({ type: "notInSet", lines: incorrectLines });
  }
  if (missing > 0) {
    jQuery("#ul-" + elemId).addClass("incorrect");
    errors.push(parson.translations.lines_missing());
    logErrors.push({ type: "linesMissing", lines: missing });
  }

  return {
    errors: errors,
    log_errors: logErrors,
    success: errors.length === 0
  };
};

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
    // A categorization problem grades membership rather than order, so its
    // answer box is filled rather than built, and its labels say so.
    var unordered = config.unordered === true;
    var answerNoun = config.answerNoun || (unordered ? "items" : "lines");

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
      grader: unordered ? SetBasedGrader : undefined,
      trash_label: "Available lines",
      solution_label:
        (unordered ? "Place your answer here (" : "Build your answer here (") +
        solutionLineCount + " " + answerNoun + ")",
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
          fbDiv.textContent = unordered
            ? "Not quite yet. Check that everything in the answer belongs there, and that nothing is missing."
            : "Not quite yet. Check the order, and make sure you've left every distractor in the available lines.";
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
    var fbDiv = document.getElementById(config.id + "-feedback");
    if (trashDiv) {
      trashDiv.classList.add("parsons-source");
    }
    if (sortableDiv) {
      sortableDiv.classList.add("parsons-answer");
    }
    if (fbDiv) {
      fbDiv.setAttribute("role", "status");
      fbDiv.setAttribute("aria-live", "polite");
      fbDiv.setAttribute("aria-atomic", "true");
    }

    // Keyboard route alongside drag-and-drop. Nothing is added to the cards
    // themselves -- adding per-card buttons squeezed the code text -- so the
    // cards carry the interaction: arrow keys move focus within a list, Enter
    // or Space moves a card between the available lines and the answer, and
    // Alt with an arrow key reorders a card already in the answer.
    var keyboardStatus = null;

    function currentLists() {
      return {
        source: document.getElementById("ul-" + config.id + "-trash"),
        answer: document.getElementById("ul-" + config.id + "-sortable")
      };
    }

    function clearVisibleFeedback() {
      widget.clearFeedback();
      if (fbDiv) {
        fbDiv.textContent = "";
        fbDiv.className = "parsons-feedback";
      }
    }

    function announce(message) {
      if (!keyboardStatus) return;
      keyboardStatus.textContent = "";
      window.requestAnimationFrame(function () {
        keyboardStatus.textContent = message;
      });
    }

    function shortCardText(card) {
      var text = card.textContent.replace(/\s+/g, " ").trim();
      return text.length > 80 ? text.slice(0, 77) + "..." : text;
    }

    function refreshSortables() {
      var lists = currentLists();
      [lists.source, lists.answer].forEach(function (list) {
        if (list && jQuery(list).hasClass("ui-sortable")) {
          jQuery(list).sortable("refresh");
        }
      });
    }

    function finishKeyboardMove(card, message, logType) {
      var line = widget.getLineById(card.id);
      if (line) {
        line.indent = 0;
        widget.updateHTMLIndent(card.id);
      }
      refreshSortables();
      widget.addLogEntry({ type: logType, target: card.id }, true);
      enhanceKeyboardControls(card);
      synchronizeCardAndBinHeights();
      announce(message);
    }

    // Roving tabindex: one card per list is a tab stop, and the arrow keys
    // move both the focus and the tab stop among the rest.
    function setRovingFocus(card) {
      if (!card.parentNode) return;
      Array.prototype.forEach.call(card.parentNode.children, function (sibling) {
        sibling.setAttribute("tabindex", sibling === card ? "0" : "-1");
      });
    }

    function applyDefaultRoving(list) {
      Array.prototype.forEach.call(list.children, function (card, index) {
        card.setAttribute("tabindex", index === 0 ? "0" : "-1");
      });
    }

    function moveFocus(card, offset) {
      if (!card.parentNode) return;
      var siblings = Array.prototype.slice.call(card.parentNode.children);
      var target = siblings[siblings.indexOf(card) + offset];
      if (!target) return;
      setRovingFocus(target);
      target.focus();
    }

    function toggleList(card) {
      var lists = currentLists();
      if (!lists.source || !lists.answer) return;

      clearVisibleFeedback();
      var label = shortCardText(card);

      if (card.parentNode === lists.answer) {
        lists.source.appendChild(card);
        finishKeyboardMove(
          card,
          "Moved " + label + " back to available lines.",
          "removeOutput"
        );
      } else {
        lists.answer.appendChild(card);
        finishKeyboardMove(
          card,
          "Moved " + label + " to answer position " +
            lists.answer.children.length + ".",
          "addOutput"
        );
      }
    }

    function reorderCard(card, offset) {
      var lists = currentLists();
      if (!lists.answer || card.parentNode !== lists.answer) return;

      clearVisibleFeedback();

      if (offset < 0) {
        var previous = card.previousElementSibling;
        if (!previous) return;
        lists.answer.insertBefore(card, previous);
      } else {
        var next = card.nextElementSibling;
        if (!next) return;
        lists.answer.insertBefore(next, card);
      }

      var cards = Array.prototype.slice.call(lists.answer.children);
      finishKeyboardMove(
        card,
        "Moved " + shortCardText(card) + " to answer position " +
          (cards.indexOf(card) + 1) + " of " + cards.length + ".",
        "moveOutput"
      );
    }

    function handleCardKeydown(event) {
      var card = event.currentTarget;
      var key = event.key;

      if (key === "Enter" || key === " " || key === "Spacebar") {
        event.preventDefault();
        toggleList(card);
        return;
      }

      if (key !== "ArrowUp" && key !== "ArrowDown") return;
      event.preventDefault();

      var offset = key === "ArrowUp" ? -1 : 1;
      var reordering = event.altKey || event.ctrlKey || event.metaKey;
      if (!reordering) {
        moveFocus(card, offset);
      } else if (!unordered) {
        reorderCard(card, offset);
      }
    }

    function decorateCard(card) {
      card.setAttribute("tabindex", "-1");
      if (!card.dataset.parsonsKeyboardBound) {
        card.addEventListener("keydown", handleCardKeydown);
        card.dataset.parsonsKeyboardBound = "true";
      }
    }

    function bindSortableUpdates() {
      var lists = currentLists();
      [lists.source, lists.answer].forEach(function (list) {
        if (!list) return;
        jQuery(list)
          .off(".parsonsKeyboard")
          .on("sortstart.parsonsKeyboard", clearVisibleFeedback)
          .on("sortupdate.parsonsKeyboard sortreceive.parsonsKeyboard", function () {
            window.requestAnimationFrame(function () {
              enhanceKeyboardControls();
              synchronizeCardAndBinHeights();
            });
          });
      });
    }

    function enhanceKeyboardControls(cardToFocus) {
      if (!problemRoot) return;

      var help = problemRoot.querySelector(".parsons-keyboard-help");
      if (!help) {
        help = document.createElement("p");
        help.id = config.id + "-keyboard-help";
        help.className = "parsons-keyboard-help";
        help.textContent = unordered
          ? "Keyboard: tab into a list, move between lines with the up and down arrow keys, and press Enter or Space to move a line into or out of the answer."
          : "Keyboard: tab into a list, move between lines with the up and down arrow keys, press Enter or Space to move a line into or out of the answer, and hold Alt with an arrow key to reorder a line already in the answer.";
        problemRoot.insertBefore(help, trashDiv);
      }

      if (!keyboardStatus) {
        keyboardStatus = document.createElement("span");
        keyboardStatus.className = "visually-hidden";
        keyboardStatus.setAttribute("role", "status");
        keyboardStatus.setAttribute("aria-live", "polite");
        keyboardStatus.setAttribute("aria-atomic", "true");
        problemRoot.appendChild(keyboardStatus);
      }

      var lists = currentLists();
      if (!lists.source || !lists.answer) return;

      var sourceLabel = trashDiv ? trashDiv.querySelector(":scope > p") : null;
      var answerLabel = sortableDiv ? sortableDiv.querySelector(":scope > p") : null;
      if (sourceLabel) {
        sourceLabel.id = config.id + "-source-label";
        lists.source.setAttribute("aria-labelledby", sourceLabel.id);
      }
      if (answerLabel) {
        answerLabel.id = config.id + "-answer-label";
        lists.answer.setAttribute("aria-labelledby", answerLabel.id);
      }
      lists.source.setAttribute("aria-describedby", help.id);
      lists.answer.setAttribute("aria-describedby", help.id);

      Array.prototype.forEach.call(lists.source.children, decorateCard);
      Array.prototype.forEach.call(lists.answer.children, decorateCard);
      applyDefaultRoving(lists.source);
      applyDefaultRoving(lists.answer);

      bindSortableUpdates();

      if (cardToFocus && document.contains(cardToFocus)) {
        setRovingFocus(cardToFocus);
        cardToFocus.focus();
      }
    }
    // Let every card wrap naturally, measure the tallest one, and then use
    // that height for every card and every answer bin. Computing the answer
    // height here also avoids unsupported CSS multiplication of a length by
    // the number of solution lines.
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

        var answerUl = document.getElementById("ul-" + config.id + "-sortable");
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

    enhanceKeyboardControls();
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
        enhanceKeyboardControls();
        synchronizeCardAndBinHeights();
        if (fbDiv) {
          fbDiv.textContent = "";
          fbDiv.className = "parsons-feedback";
        }
        announce("The available lines have been shuffled and the answer cleared.");
      });
    }
  });
});
