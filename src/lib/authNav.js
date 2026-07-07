import { supabase } from './supabase.js';

// --- Logout confirmation modal ---

const MODAL_CSS = `
#signout-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 9900;
  display: flex;
  align-items: center;
  justify-content: center;
}

#signout-overlay[hidden] {
  display: none;
}

#signout-dialog {
  background: var(--panel, #fff);
  border: 1px solid var(--line, #e8ddc8);
  border-radius: 14px;
  padding: 36px 32px 28px;
  max-width: 360px;
  width: 90%;
  text-align: center;
  box-shadow: var(--shadow, 0 16px 38px rgba(65,48,25,0.10));
}

#signout-dialog p {
  margin: 0 0 28px;
  font-size: 1.05rem;
  color: var(--text, #1a1a1a);
  line-height: 1.5;
}

#signout-dialog .modal-actions {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
}
`;

function injectModal() {
  if (document.getElementById('signout-overlay')) return;

  const style = document.createElement('style');
  style.textContent = MODAL_CSS;
  document.head.appendChild(style);

  const overlay = document.createElement('div');
  overlay.id = 'signout-overlay';
  overlay.hidden = true;
  overlay.setAttribute('role', 'dialog');
  overlay.setAttribute('aria-modal', 'true');
  overlay.setAttribute('aria-labelledby', 'signout-dialog-label');
  overlay.innerHTML = `
    <div id="signout-dialog">
      <p id="signout-dialog-label">Biztos ki szeretnél jelentkezni?</p>
      <div class="modal-actions">
        <button id="signout-confirm" class="btn" type="button">Igen</button>
        <button id="signout-cancel" class="ghost-btn" type="button">Nem</button>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);

  document.getElementById('signout-confirm').addEventListener('click', async () => {
    closeModal();
    await supabase.auth.signOut();
    window.location.href = 'index.html';
  });

  document.getElementById('signout-cancel').addEventListener('click', closeModal);

  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && !overlay.hidden) closeModal();
  });

  // Stop clicks inside the dialog from bubbling to the overlay
  document.getElementById('signout-dialog').addEventListener('click', e => e.stopPropagation());
}

function openModal() {
  const overlay = document.getElementById('signout-overlay');
  overlay.hidden = false;
  document.getElementById('signout-cancel').focus();
}

function closeModal() {
  document.getElementById('signout-overlay').hidden = true;
}

// ---

export function initAuthNav() {
  injectModal();

  // Show confirmation modal instead of signing out immediately
  document.querySelectorAll('[data-auth-signout]').forEach(btn => {
    btn.addEventListener('click', e => {
      e.preventDefault();
      openModal();
    });
  });

  // Apply initial state from cached session (reads localStorage, near-instant).
  // If the session can't be resolved for any reason, fall back to logged-out
  // nav so Bejelentkezés/Regisztráció are never left hidden indefinitely.
  supabase.auth.getSession()
    .then(({ data: { session } }) => {
      setAuthState(!!session);
    })
    .catch(err => {
      console.warn('Auth navigation fallback: session could not be resolved, showing logged-out navigation.', err);
      setAuthState(false);
    });

  // Keep nav in sync on sign-in, sign-out, token expiry, or other-tab changes
  try {
    supabase.auth.onAuthStateChange((_event, session) => {
      setAuthState(!!session);
    });
  } catch (err) {
    console.warn('Auth navigation fallback: session could not be resolved, showing logged-out navigation.', err);
    setAuthState(false);
  }
}

function setAuthState(loggedIn) {
  const show = loggedIn ? 'logged-in' : 'logged-out';
  const hide = loggedIn ? 'logged-out' : 'logged-in';

  // Inline style beats all CSS rules — this is the reliable show/hide mechanism
  document.querySelectorAll(`[data-auth-visible="${show}"]`).forEach(el => {
    el.style.display = 'inline-flex';
  });
  document.querySelectorAll(`[data-auth-visible="${hide}"]`).forEach(el => {
    el.style.removeProperty('display');
  });
}
