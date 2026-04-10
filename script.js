document.addEventListener("DOMContentLoaded", function () {
  var btn = document.getElementById("servo-expand-btn");
  var detail = document.getElementById("servo-detail");

  if (!btn || !detail) return;

  btn.addEventListener("click", function () {
    if (detail.style.display === "none" || detail.style.display === "") {
      detail.style.display = "block";
      this.textContent = "Свернуть ▲";
    } else {
      detail.style.display = "none";
      this.textContent = "Развернуть подробный разбор ▼";
    }
  });
});

