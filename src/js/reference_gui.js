// Browser-side helpers for the course reference GUI
// (src/reference/reference_gui.qmd). Styling for the classes used here lives
// in the .gui-* rules of src/css/reference_gui.scss.

(function () {
  "use strict";

  // Copy text to the clipboard and flash the element that asked for it.

  function copyText(text, flashId) {
    var done = function () {
      if (!flashId) return;
      var el = document.getElementById(flashId);
      if (!el) return;
      el.classList.remove("gui-copied");
      void el.offsetWidth;
      el.classList.add("gui-copied");
    };

    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).then(done, function () {
        fallbackCopy(text);
        done();
      });
    } else {
      fallbackCopy(text);
      done();
    }
  }

  // Clipboard fallback for pages served over plain http.

  function fallbackCopy(text) {
    var area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    try {
      document.execCommand("copy");
    } catch (e) {
      // Nothing more to try -- the text stays selected for a manual copy.
    }
    document.body.removeChild(area);
  }

  // Track unsaved edits so a page reload or close can be confirmed first.

  var dirty = false;

  function markDirty() {
    dirty = true;
    document.body.classList.add("gui-dirty");
  }

  function markClean() {
    dirty = false;
    document.body.classList.remove("gui-dirty");
  }

  document.addEventListener("input", function (event) {
    if (event.target.closest(".gui-card")) markDirty();
  });

  window.addEventListener("beforeunload", function (event) {
    if (!dirty) return;
    event.preventDefault();
    event.returnValue = "";
  });

  // Ctrl/Cmd + S saves the editor the cursor is currently in.

  document.addEventListener("keydown", function (event) {
    if (!(event.ctrlKey || event.metaKey) || event.key.toLowerCase() !== "s") {
      return;
    }
    var card = document.activeElement
      ? document.activeElement.closest(".gui-card")
      : null;
    var save = card ? card.querySelector(".gui-save") : null;
    if (!save) save = document.querySelector(".tab-pane.active .gui-save");
    if (!save) return;
    event.preventDefault();
    save.click();
  });

  // Message handlers called from the server with session$sendCustomMessage().

  if (window.Shiny) {
    Shiny.addCustomMessageHandler("reference_gui_copy", function (message) {
      copyText(message.text, message.flash);
    });

    Shiny.addCustomMessageHandler("reference_gui_clean", function () {
      markClean();
    });
  }
})();
