// Accordion toggle behavior for course lesson pages (Reference section:
// Glossary / Functions / Keyboard shortcuts / R Studio panes).
//
// This was previously copy-pasted -- with drifting whitespace -- into the
// bottom of every lesson .qmd. It's centralized here so there's a single
// canonical version. Adapted from the more general accordion-group-aware
// version in gits/nest_study/recycling/outputs/nest_app/src/js/accordion.js,
// simplified back to a flat button list since lesson Reference sections
// don't (yet) need more than one independent accordion group per page.
// If a lesson ever needs multiple independent accordion groups, port the
// `.accordion-group` scoping logic back in from that source.

document.addEventListener("DOMContentLoaded", function () {
  var acc = document.getElementsByClassName("accordion");

  for (var i = 0; i < acc.length; i++) {
    // Panels are closed by default:

    acc[i].classList.remove("active");

    var panel = acc[i].nextElementSibling;
    if (panel && panel.classList.contains("panel")) {
      panel.style.display = "none";
    }

    // Listen for clicks/taps to toggle a panel open or closed:

    acc[i].addEventListener("click", function () {
      this.classList.toggle("active");

      var panel = this.nextElementSibling;
      if (!panel || !panel.classList.contains("panel")) return;

      if (panel.style.display === "block") {
        panel.style.display = "none";
      } else {
        panel.style.display = "block";
      }
    });
  }
});
