// Two-column "matching game" exercises for course lesson pages.
//
// Students click an item in the left column, then an item in the right column,
// to pair them. Each pairing is shown with a shared number badge and colour on
// both items. "Check My Matches" grades the pairings; "Shuffle Again" reshuffles
// the right column and clears all matches.
//
// Markup (normally emitted by the matching_game() R helper in
// src/r/course_functions.R):
//   <div class="matching-game" id="<id>">
//     <div class="matching-col matching-left"  id="<id>-left"></div>
//     <div class="matching-col matching-right" id="<id>-right"></div>
//     <div style="clear: both;"></div>
//     <button id="<id>-check" ...>Check My Matches</button>
//     <button id="<id>-reset" ...>Shuffle Again</button>
//     <p id="<id>-feedback" class="parsons-feedback"></p>
//   </div>
// ...then registers itself with:
//   window.matchingGames = window.matchingGames || [];
//   window.matchingGames.push({
//     id: "m-0-1-01",
//     osSwitch: true,                 // optional; see below
//     pairs: [ { left: ..., right: "..." }, ... ]
//   });
//
// A pair's `left` may be:
//   * a string (HTML allowed), or
//   * an object { mac: "<html>", win: "<html>" } when osSwitch is true, in
//     which case a "macOS / Windows-Linux" toggle is shown and the left column
//     displays the variant for the selected operating system.
//
// Correct pairing is by position: left item i matches right item i. The right
// column is shuffled on load. Registration just pushes onto a global array, so
// load order does not matter; this file initialises every registered game once
// the DOM is ready and is safe to load more than once.

(function () {
  "use strict";

  var PALETTE = [
    "#1565C0", "#2E7D32", "#6A1B9A", "#C62828", "#EF6C00",
    "#00838F", "#AD1457", "#4E342E", "#283593", "#558B2F"
  ];

  function colorFor(num) {
    return PALETTE[(num - 1) % PALETTE.length];
  }

  function shuffle(arr) {
    var a = arr.slice();
    for (var i = a.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var tmp = a[i];
      a[i] = a[j];
      a[j] = tmp;
    }
    return a;
  }

  function detectOS() {
    var s = (navigator.platform || "") + " " + (navigator.userAgent || "");
    return /Mac|iPhone|iPad|iPod/i.test(s) ? "mac" : "win";
  }

  function initGame(config) {
    var root = document.getElementById(config.id);
    if (!root || root.dataset.mgInit === "true") {
      return;
    }
    root.dataset.mgInit = "true";

    var leftBox = document.getElementById(config.id + "-left");
    var rightBox = document.getElementById(config.id + "-right");
    var feedback = document.getElementById(config.id + "-feedback");
    if (!leftBox || !rightBox) {
      return;
    }

    var pairs = config.pairs || [];
    var leftOrder = pairs.map(function (_p, i) { return i; });   // source order
    var rightOrder = shuffle(leftOrder);                         // shuffled

    var selectedLeft = null;   // pair index of the currently selected left item
    var matches = {};          // leftPairIndex -> rightPairIndex
    var currentOS = detectOS();

    function leftHTML(pairIdx) {
      var lft = pairs[pairIdx].left;
      if (lft && typeof lft === "object") {
        return lft[currentOS] || lft.mac || lft.win || "";
      }
      return lft;
    }

    function numForLeft(pairIdx) {
      return leftOrder.indexOf(pairIdx) + 1;
    }

    function rightOwner(rightPairIdx) {
      var owner = null;
      Object.keys(matches).forEach(function (lp) {
        if (matches[lp] === rightPairIdx) {
          owner = Number(lp);
        }
      });
      return owner;
    }

    function clearFeedback() {
      if (feedback) {
        feedback.textContent = "";
        feedback.className = "parsons-feedback";
      }
    }

    function makeItem(pairIdx, side) {
      var el = document.createElement("div");
      el.className = "matching-item matching-" + side + "-item";
      el.dataset.pair = pairIdx;

      var badge = document.createElement("span");
      badge.className = "matching-badge";

      var label = document.createElement("span");
      label.className = "matching-label";
      label.innerHTML = side === "left" ? leftHTML(pairIdx) : pairs[pairIdx].right;

      el.appendChild(badge);
      el.appendChild(label);
      return { el: el, badge: badge };
    }

    function paint(el, badge, num) {
      if (num) {
        badge.textContent = num;
        badge.style.backgroundColor = colorFor(num);
        el.style.borderColor = colorFor(num);
        el.classList.add("matching-matched");
      } else {
        badge.textContent = "";
        badge.style.backgroundColor = "";
        el.style.borderColor = "";
        el.classList.remove("matching-matched");
      }
    }

    function render() {
      leftBox.innerHTML = "";
      rightBox.innerHTML = "";

      leftOrder.forEach(function (pairIdx) {
        var made = makeItem(pairIdx, "left");
        var matched = Object.prototype.hasOwnProperty.call(matches, pairIdx);
        paint(made.el, made.badge, matched ? numForLeft(pairIdx) : null);
        if (selectedLeft === pairIdx) {
          made.el.classList.add("selected");
        }
        made.el.addEventListener("click", function () { onLeftClick(pairIdx); });
        leftBox.appendChild(made.el);
      });

      rightOrder.forEach(function (pairIdx) {
        var made = makeItem(pairIdx, "right");
        var owner = rightOwner(pairIdx);
        paint(made.el, made.badge, owner === null ? null : numForLeft(owner));
        made.el.addEventListener("click", function () { onRightClick(pairIdx); });
        rightBox.appendChild(made.el);
      });
    }

    function onLeftClick(pairIdx) {
      clearFeedback();
      selectedLeft = (selectedLeft === pairIdx) ? null : pairIdx;
      render();
    }

    function onRightClick(pairIdx) {
      clearFeedback();
      if (selectedLeft === null) {
        var owner = rightOwner(pairIdx);
        if (owner !== null) {
          delete matches[owner];
          render();
        }
        return;
      }
      if (matches[selectedLeft] === pairIdx) {
        delete matches[selectedLeft];
      } else {
        var prevOwner = rightOwner(pairIdx);
        if (prevOwner !== null) {
          delete matches[prevOwner];
        }
        matches[selectedLeft] = pairIdx;
      }
      selectedLeft = null;
      render();
    }

    function check() {
      clearFeedback();
      root.querySelectorAll(".matching-item").forEach(function (el) {
        el.classList.remove("matching-correct", "matching-incorrect");
      });

      var correct = 0;
      leftOrder.forEach(function (pairIdx) {
        var leftEl = leftBox.querySelector(
          '.matching-left-item[data-pair="' + pairIdx + '"]');
        var matchedRight = matches[pairIdx];
        if (matchedRight === undefined) {
          if (leftEl) { leftEl.classList.add("matching-incorrect"); }
          return;
        }
        var rightEl = rightBox.querySelector(
          '.matching-right-item[data-pair="' + matchedRight + '"]');
        if (matchedRight === pairIdx) {
          correct++;
          if (leftEl) { leftEl.classList.add("matching-correct"); }
          if (rightEl) { rightEl.classList.add("matching-correct"); }
        } else {
          if (leftEl) { leftEl.classList.add("matching-incorrect"); }
          if (rightEl) { rightEl.classList.add("matching-incorrect"); }
        }
      });

      if (feedback) {
        if (correct === pairs.length) {
          feedback.textContent = "All matched -- nice work!";
          feedback.className = "parsons-feedback parsons-feedback-correct";
        } else {
          feedback.textContent = "You matched " + correct + " of " + pairs.length +
            " correctly. Adjust the highlighted items and check again.";
          feedback.className = "parsons-feedback parsons-feedback-incorrect";
        }
      }
    }

    function reset() {
      matches = {};
      selectedLeft = null;
      rightOrder = shuffle(leftOrder);
      clearFeedback();
      render();
    }

    // Optional macOS / Windows-Linux toggle, shown above the columns.
    if (config.osSwitch) {
      var sw = document.createElement("div");
      sw.className = "matching-os-switch";
      sw.innerHTML =
        '<span class="matching-os-label">Show shortcuts for:</span>' +
        '<div class="matching-os-toggle" role="group" aria-label="Operating system">' +
          '<button type="button" class="matching-os-btn" data-os="mac">macOS</button>' +
          '<button type="button" class="matching-os-btn" data-os="win">Windows / Linux</button>' +
        '</div>';
      root.insertBefore(sw, leftBox);
      var osButtons = sw.querySelectorAll(".matching-os-btn");
      osButtons.forEach(function (btn) {
        if (btn.dataset.os === currentOS) { btn.classList.add("active"); }
        btn.addEventListener("click", function () {
          if (currentOS === btn.dataset.os) { return; }
          currentOS = btn.dataset.os;
          osButtons.forEach(function (b) {
            b.classList.toggle("active", b.dataset.os === currentOS);
          });
          render();   // relabel the left column; matches are preserved
        });
      });
    }

    var checkBtn = document.getElementById(config.id + "-check");
    if (checkBtn) { checkBtn.addEventListener("click", check); }
    var resetBtn = document.getElementById(config.id + "-reset");
    if (resetBtn) { resetBtn.addEventListener("click", reset); }

    render();
  }

  function initAll() {
    (window.matchingGames || []).forEach(initGame);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }

  window.__initMatchingGames = initAll;
})();
