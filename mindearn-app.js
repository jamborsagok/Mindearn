import MindEarnSettings from './mindearn-config.js';

const labels = {
  active: "Aktív",
  building: "Épül",
  planned: "Előkészítve",
  waiting: "Bekötésre vár"
};

const eventQueue = [];

function track(name, detail) {
  const payload = {
    name,
    detail: detail || {},
    page: location.pathname.split("/").pop() || "index.html",
    at: new Date().toISOString()
  };

  eventQueue.push(payload);
  document.documentElement.dataset.mindearnEvents = String(eventQueue.length);

  if (MindEarnSettings.analyticsEndpoint) {
    navigator.sendBeacon(
      MindEarnSettings.analyticsEndpoint,
      new Blob([JSON.stringify(payload)], { type: "application/json" })
    );
  }
}

function wireTracking() {
  document.addEventListener("click", (event) => {
    const target = event.target.closest("a, button");
    if (!target) return;

    const label = (target.textContent || target.getAttribute("aria-label") || "").trim();
    const href = target.getAttribute("href") || "";
    track("click", { label, href });
  });
}

function wireSubscriptionForms() {
  document.querySelectorAll("[data-subscribe-form]").forEach((form) => {
    const status = form.querySelector("[data-form-status]");

    form.addEventListener("submit", async (event) => {
      event.preventDefault();

      const data = Object.fromEntries(new FormData(form).entries());
      track("subscribe_request", { interest: data.interest || "MindEarn" });

      if (MindEarnSettings.subscribeEndpoint) {
        try {
          const response = await fetch(MindEarnSettings.subscribeEndpoint, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(data)
          });
          if (!response.ok) throw new Error("Endpoint hiba");
          if (status) status.textContent = "Köszönöm, a feliratkozás rögzítve.";
          form.reset();
          return;
        } catch {
          if (status) status.textContent = "Az űrlap készen áll, az endpoint beállítása következik.";
          return;
        }
      }

      const subject = encodeURIComponent("MindEarn feliratkozás");
      const body = encodeURIComponent(
        `Név: ${data.name || ""}\nEmail: ${data.email || ""}\nÉrdeklődés: ${data.interest || ""}`
      );
      if (status) {
        status.innerHTML = `Az űrlap készen áll. <a href="mailto:${MindEarnSettings.leadEmail}?subject=${subject}&body=${body}">Email küldése</a>`;
      }
    });
  });
}

function wireLeadPopup() {
  const popup = document.querySelector("[data-lead-popup]");
  if (!popup) return;

  const storageKey = "mindearnLeadPopupClosed";
  const delayMs = 10000;

  function storageClosed() {
    try {
      return sessionStorage.getItem(storageKey) === "1";
    } catch {
      return false;
    }
  }

  function markClosed() {
    try {
      sessionStorage.setItem(storageKey, "1");
    } catch {
      document.documentElement.dataset.leadPopupClosed = "1";
    }
  }

  function openPopup() {
    if (storageClosed()) return;
    popup.hidden = false;
    document.body.classList.add("lead-popup-open");
    track("lead_popup_open", { delayMs });
  }

  function closePopup() {
    popup.hidden = true;
    document.body.classList.remove("lead-popup-open");
    markClosed();
    track("lead_popup_close");
  }

  window.setTimeout(openPopup, delayMs);

  popup.querySelectorAll("[data-lead-popup-close]").forEach((control) => {
    control.addEventListener("click", closePopup);
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !popup.hidden) closePopup();
  });
}

function applyAccessState() {
  document.querySelectorAll("[data-access-key]").forEach((item) => {
    const key = item.dataset.accessKey;
    const state = MindEarnSettings.access[key] || "waiting";
    const label = labels[state] || labels.waiting;
    const badge = item.querySelector("[data-access-status]");
    item.dataset.accessState = state;
    if (badge) badge.textContent = label;
  });
}

wireTracking();
wireSubscriptionForms();
wireLeadPopup();
applyAccessState();
track("page_view");

if (import.meta.env.DEV) {
  import('./src/utils/healthCheck.js').then(({ checkSupabaseConnection }) => {
    checkSupabaseConnection();
  });
}
