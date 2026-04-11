/**
 * Отладка формы: откройте главную с ?debugForm=1 или в консоли:
 * sessionStorage.setItem('kvt_debug_form','1'); location.reload();
 */
function kvtFormDebugEnabled() {
  try {
    if (typeof window === "undefined" || !window.location) return false;
    if (/[?&]debugForm=1(?:&|$)/.test(String(window.location.search))) return true;
    if (window.sessionStorage && window.sessionStorage.getItem("kvt_debug_form") === "1") return true;
  } catch (e) {
    /* private mode и т.п. */
  }
  return false;
}

function kvtFormLog(msg) {
  if (kvtFormDebugEnabled() && typeof console !== "undefined" && console.log) {
    console.log(msg);
  }
}

function initKvtServoExpand() {
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
}

/**
 * Formspree без редиректа: fetch + Accept: application/json.
 * При сбоях доставки проверьте endpoint и подтверждение формы/email в Formspree.
 */
function initKvtContactFormAjax() {
  var form =
    document.getElementById("contact-form") ||
    document.querySelector("#contacts form[action*='formspree']") ||
    document.querySelector("#contacts form");

  if (!form) {
    kvtFormLog("contact form NOT found (нет #contact-form и формы в #contacts)");
    return;
  }

  if (form.dataset.kvtAjaxBound === "1") {
    kvtFormLog("contact form: обработчик уже привязан, пропуск");
    return;
  }

  if (!form.action || String(form.action).indexOf("formspree") === -1) {
    kvtFormLog("contact form found, но action не похож на Formspree — привязка всё равно выполняется");
  }

  kvtFormLog("contact form found");
  form.dataset.kvtAjaxBound = "1";

  var modal = document.getElementById("kvt-success-modal");
  var errorEl = document.getElementById("contact-form-error");
  var submitBtn = form.querySelector('button[type="submit"]');
  var defaultBtnText = submitBtn ? submitBtn.textContent.trim() : "Отправить заявку";
  var lastFocus = null;

  function showError(msg) {
    if (!errorEl) return;
    errorEl.textContent = msg;
    errorEl.hidden = false;
  }

  function hideError() {
    if (!errorEl) return;
    errorEl.textContent = "";
    errorEl.hidden = true;
  }

  function parseFormspreeError(data) {
    if (!data || typeof data !== "object") return "";
    if (typeof data.error === "string") return data.error;
    if (data.errors && typeof data.errors === "object") {
      var parts = [];
      Object.keys(data.errors).forEach(function (key) {
        var v = data.errors[key];
        if (typeof v === "string") parts.push(v);
        else if (Array.isArray(v)) parts.push(v.join(", "));
      });
      if (parts.length) return parts.join(" ");
    }
    return "";
  }

  function onModalKeydown(e) {
    if (!modal || modal.hidden) return;
    if (e.key === "Escape") {
      e.preventDefault();
      closeModal();
      return;
    }
    if (e.key === "Tab") {
      var closeBtn = modal.querySelector(".kvt-modal__close");
      if (closeBtn) {
        e.preventDefault();
        closeBtn.focus();
      }
    }
  }

  function openModal(focusReturnEl) {
    if (!modal) return;
    lastFocus = focusReturnEl && typeof focusReturnEl.focus === "function" ? focusReturnEl : submitBtn;
    modal.hidden = false;
    modal.classList.add("kvt-modal--open");
    document.body.classList.add("kvt-modal-open");
    document.addEventListener("keydown", onModalKeydown);
    var closeBtn = modal.querySelector(".kvt-modal__close");
    if (closeBtn) {
      window.requestAnimationFrame(function () {
        closeBtn.focus();
      });
    }
  }

  function closeModal() {
    if (!modal) return;
    modal.classList.remove("kvt-modal--open");
    modal.hidden = true;
    document.body.classList.remove("kvt-modal-open");
    document.removeEventListener("keydown", onModalKeydown);
    if (lastFocus && typeof lastFocus.focus === "function") {
      lastFocus.focus();
    } else if (submitBtn) {
      submitBtn.focus();
    }
    lastFocus = null;
  }

  if (modal) {
    modal.addEventListener("click", function (e) {
      if (e.target.closest("[data-kvt-modal-dismiss]")) closeModal();
    });
  }

  function onFormSubmit(e) {
    e.preventDefault();
    e.stopPropagation();
    kvtFormLog("submit intercepted");

    if (form.getAttribute("data-submitting") === "1") {
      kvtFormLog("submit ignored: уже идёт отправка");
      return;
    }

    var focusAfterClose = submitBtn || document.activeElement;

    hideError();
    form.setAttribute("data-submitting", "1");
    form.setAttribute("aria-busy", "true");
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.setAttribute("aria-busy", "true");
      submitBtn.textContent = "Отправка...";
    }

    var action = form.getAttribute("action");
    if (!action) {
      form.removeAttribute("data-submitting");
      form.removeAttribute("aria-busy");
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.removeAttribute("aria-busy");
        submitBtn.textContent = defaultBtnText;
      }
      showError("Форма настроена некорректно. Сообщите администратору сайта.");
      return;
    }

    kvtFormLog("fetch started");

    fetch(action, {
      method: "POST",
      body: new FormData(form),
      headers: {
        Accept: "application/json",
      },
    })
      .then(function (response) {
        return response
          .json()
          .then(function (data) {
            return { ok: response.ok, status: response.status, data: data };
          })
          .catch(function () {
            return { ok: false, status: response.status, data: null, badJson: true };
          });
      })
      .catch(function () {
        return { ok: false, status: 0, data: null, network: true };
      })
      .then(function (result) {
        form.removeAttribute("data-submitting");
        form.removeAttribute("aria-busy");
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.removeAttribute("aria-busy");
          submitBtn.textContent = defaultBtnText;
        }

        if (result.ok) {
          kvtFormLog("success response");
          form.reset();
          kvtFormLog("form reset executed");
          hideError();
          openModal(focusAfterClose);
          return;
        }

        kvtFormLog("error response: " + (result.status || "") + " " + JSON.stringify(result.data || {}));

        var detailMsg = parseFormspreeError(result.data);
        var msg =
          detailMsg ||
          "Не удалось отправить заявку. Попробуйте ещё раз или напишите на указанный в разделе контактов email.";
        if (result.network) {
          msg = "Нет соединения с сервером. Проверьте интернет и попробуйте снова.";
        } else if (result.badJson) {
          msg = "Сервер ответил неожиданно. Попробуйте позже.";
        }
        showError(msg);
      });
  }

  /* capture: true — срабатывает до всплытия; stopPropagation в обработчике блокирует обычный submit */
  form.addEventListener("submit", onFormSubmit, true);
}

function initKvtHamburger() {
  var btn = document.getElementById("hamburger");
  var menu = document.getElementById("mobile-menu");
  if (!btn || !menu) return;
  btn.addEventListener("click", function () {
    var open = menu.classList.toggle("open");
    btn.classList.toggle("active", open);
    btn.setAttribute("aria-expanded", open ? "true" : "false");
  });
  var links = menu.querySelectorAll("a");
  for (var i = 0; i < links.length; i++) {
    links[i].addEventListener("click", function () {
      menu.classList.remove("open");
      btn.classList.remove("active");
      btn.setAttribute("aria-expanded", "false");
    });
  }
}

function initKvtScrollReveal() {
  var targets = document.querySelectorAll(".product-card, .education-block, .article-card, .section-title");
  if (!("IntersectionObserver" in window)) {
    for (var j = 0; j < targets.length; j++) {
      targets[j].classList.add("fade-in", "visible");
    }
    return;
  }
  var observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
        }
      });
    },
    { threshold: 0.1 }
  );
  for (var k = 0; k < targets.length; k++) {
    targets[k].classList.add("fade-in");
    observer.observe(targets[k]);
  }
}

function initKvtSite() {
  initKvtServoExpand();
  initKvtContactFormAjax();
  initKvtHamburger();
  initKvtScrollReveal();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initKvtSite, { once: true });
} else {
  initKvtSite();
}
