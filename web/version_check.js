/*
 * SpeakFlow — version check + service-worker update bridge.
 *
 * Loaded by index.html *before* flutter_bootstrap.js so that:
 *   1. We capture the SW's `updatefound` / `controllerchange` events
 *      from the very first registration (no race with Flutter boot).
 *   2. We expose hooks on `window.__speakflowUpdate` that the Dart
 *      VersionService reads via `dart:js_interop`.
 *
 * Public surface (window.__speakflowUpdate):
 *   hasWaitingSW: () => boolean
 *     true if there's a service worker in the `waiting` state (new app
 *     shell downloaded, ready to activate on reload).
 *   onUpdateReady: (cb) => void
 *     register a callback fired when (a) a waiting SW appears, or
 *     (b) the controller changes. Idempotent.
 *   forceReload: () => void
 *     tell the waiting SW to skipWaiting, then hard-reload the page.
 *   getInstallId: () => string
 *     returns a stable per-tab id used for cache-busting version.json.
 *
 * The Dart side polls /version.json independently for "server deployed a
 * new build" detection — this file only handles the SW-side signals.
 */
(function (global) {
  'use strict';

  var callbacks = [];
  var waitingSW = null;

  function fire() {
    for (var i = 0; i < callbacks.length; i++) {
      try { callbacks[i](); } catch (e) { /* swallow */ }
    }
  }

  function hookSW(reg) {
    if (!reg) return;
    // A new SW has been downloaded and is waiting to activate.
    if (reg.waiting) {
      waitingSW = reg.waiting;
      fire();
    }
    reg.addEventListener('updatefound', function () {
      var newSW = reg.installing;
      if (!newSW) return;
      newSW.addEventListener('statechange', function () {
        if (newSW.state === 'installed' && reg.waiting === newSW) {
          waitingSW = newSW;
          fire();
        }
      });
    });
  }

  function setupControllerChange() {
    if (!('serviceWorker' in navigator)) return;
    navigator.serviceWorker.addEventListener('controllerchange', function () {
      // The active controller changed — usually because skipWaiting() ran.
      // Fire so Dart can refresh the UI / force a reload.
      fire();
    });
  }

  // Defer SW registration until the page has loaded so we don't compete
  // with first-paint resources. Flutter's own SW (flutter_service_worker.js)
  // is registered separately by flutter_bootstrap.js — we just hook events
  // on whatever SW the page ends up with.
  function init() {
    if (!('serviceWorker' in navigator)) return;
    setupControllerChange();
    // The Flutter SW is registered by flutter_bootstrap.js. We poll for it
    // a few times so we can attach our event listeners regardless of timing.
    var attempts = 0;
    function tryGet() {
      navigator.serviceWorker.getRegistration().then(function (reg) {
        if (reg) { hookSW(reg); }
        else if (attempts++ < 20) { setTimeout(tryGet, 500); }
      }).catch(function () { /* ignore */ });
    }
    tryGet();
  }

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    init();
  } else {
    window.addEventListener('DOMContentLoaded', init);
  }

  var installId = 'sf-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);

  global.__speakflowUpdate = {
    hasWaitingSW: function () { return !!waitingSW; },
    onUpdateReady: function (cb) {
      if (typeof cb === 'function') {
        callbacks.push(cb);
        if (waitingSW) { try { cb(); } catch (e) {} }
      }
    },
    forceReload: function () {
      if (waitingSW) {
        try { waitingSW.postMessage({ type: 'SKIP_WAITING' }); } catch (e) {}
      }
      // Updating must be deterministic. Older Flutter service workers can
      // retain a stable-named main.dart.js even when a server-version check
      // says a newer release exists. Remove every controlling SW and its
      // Cache Storage before navigating to a one-off cache-busted URL.
      var clear = [];
      if ('serviceWorker' in navigator) {
        clear.push(navigator.serviceWorker.getRegistrations().then(function (regs) {
          return Promise.all(regs.map(function (reg) { return reg.unregister(); }));
        }).catch(function () {}));
      }
      if ('caches' in global) {
        clear.push(caches.keys().then(function (keys) {
          return Promise.all(keys.map(function (key) { return caches.delete(key); }));
        }).catch(function () {}));
      }
      Promise.all(clear).then(function () {
        var sep = location.search.length === 0 ? '?' : '&';
        location.replace(location.pathname + location.search + sep +
          'sf_refresh=' + Date.now() + location.hash);
      });
    },
    triggerSwUpdate: function () {
      if (!('serviceWorker' in navigator)) return;
      navigator.serviceWorker.getRegistration().then(function (reg) {
        if (reg && typeof reg.update === 'function') {
          reg.update().catch(function () { /* ignore */ });
        }
      }).catch(function () { /* ignore */ });
    },
    onVisibilityChange: function (cb) {
      if (typeof cb !== 'function') return;
      var handler = function () {
        try { cb(document.visibilityState === 'visible'); } catch (e) {}
      };
      document.addEventListener('visibilitychange', handler);
      // Note: we intentionally do NOT fire the callback once on subscribe.
      // The Dart VersionService runs its own initial checkNow() in _init,
      // and firing here too would trigger a redundant immediate poll on
      // every page load. The callback only fires on real visibility
      // changes (tab background/foreground).
    },
    getInstallId: function () { return installId; }
  };
})(typeof window !== 'undefined' ? window : this);
