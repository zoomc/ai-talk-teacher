/*
 * SpeakFlow — PWA install prompt bridge.
 *
 * Captures `beforeinstallprompt` (Chrome / Edge / Android / desktop
 * Chromium) so the Dart side can call `promptInstall()` later from a
 * user gesture (a tap on the "Install SpeakFlow" banner).
 *
 * iOS Safari does NOT fire `beforeinstallprompt`. There is no programmatic
 * install prompt on iOS — the user must tap Share → Add to Home Screen.
 * We detect iOS Safari + not-installed and expose `isIOSSafari()` so the
 * Dart side can show a tailored banner with those instructions.
 *
 * Public surface (window.__speakflowInstall):
 *   canPromptNative: () => boolean
 *     true if `beforeinstallprompt` was captured (Chrome/Edge/Android).
 *   promptNative: () => Promise<'accepted' | 'dismissed' | 'unavailable'>
 *     triggers the native install prompt. Must be called from a user
 *     gesture (e.g. a tap handler). Rejects if not available.
 *   isIOSSafari: () => boolean
 *     true if the user is on iOS Safari (and thus needs manual A2HS).
 *   isStandalone: () => boolean
 *     true if the app is already running in standalone (installed) mode.
 *   onAvailabilityChange: (cb) => void
 *     register a callback fired when canPromptNative() flips true.
 */
(function (global) {
  'use strict';

  var deferredPrompt = null;
  var availabilityCallbacks = [];

  function fireAvailability() {
    for (var i = 0; i < availabilityCallbacks.length; i++) {
      try { availabilityCallbacks[i](); } catch (e) {}
    }
  }

  window.addEventListener('beforeinstallprompt', function (e) {
    // Prevent the mini-infobar from showing on mobile Chrome — we want
    // to use our own branded banner instead, triggered from a user gesture.
    e.preventDefault();
    deferredPrompt = e;
    fireAvailability();
  });

  window.addEventListener('appinstalled', function () {
    // Clear the deferred prompt and notify Dart so the banner hides.
    deferredPrompt = null;
    fireAvailability();
    if (global.__speakflowInstall && global.__speakflowInstall.onInstalled) {
      try { global.__speakflowInstall.onInstalled(); } catch (e) {}
    }
  });

  function isStandalone() {
    // iOS Safari
    if (window.navigator && window.navigator.standalone === true) return true;
    // Modern: CSS media query
    if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) return true;
    // Some browsers expose display-mode override values
    if (window.matchMedia && window.matchMedia('(display-mode: window-controls-overlay)').matches) return true;
    return false;
  }

  function isIOSSafari() {
    if (!navigator.userAgent) return false;
    var ua = navigator.userAgent;
    // In-app browsers (Instagram, Facebook, LinkedIn, X, Snapchat) report
    // Safari in their UA but their Share sheet doesn't surface the host
    // browser's "Add to Home Screen" — the user gets stuck. Bail out so
    // they're not shown the iOS install instructions sheet.
    if (/Instagram|FBAN|FBAV|LinkedInApp|Twitter|Snapchat/i.test(ua)) {
      return false;
    }
    var isIOS = /iPad|iPhone|iPod/.test(ua) && !window.MSStream;
    // iPadOS 13+ defaults to "Request Desktop Website" and reports a
    // macOS UA with no "iPad" token. Detect it via MacIntel platform +
    // multi-touch. This catches the bulk of modern iPads.
    if (!isIOS &&
        navigator.platform === 'MacIntel' &&
        navigator.maxTouchPoints > 1) {
      isIOS = true;
    }
    if (!isIOS) return false;
    // Safari (not Chrome on iOS, which still can't install)
    var isSafari = /^((?!CriOS|FxiOS|EdgiOS|OPiOS|GSA).)*Safari\//i.test(ua);
    return isSafari;
  }

  global.__speakflowInstall = {
    canPromptNative: function () { return !!deferredPrompt; },
    isIOSSafari: isIOSSafari,
    isStandalone: isStandalone,
    onAvailabilityChange: function (cb) {
      if (typeof cb === 'function') availabilityCallbacks.push(cb);
    },
    onInstalled: null, // Dart overwrites with a real callback
    promptNative: function () {
      return new Promise(function (resolve, reject) {
        if (!deferredPrompt) {
          reject(new Error('No install prompt available'));
          return;
        }
        var p = deferredPrompt;
        deferredPrompt = null;
        fireAvailability();
        p.prompt();
        p.userChoice.then(function (choice) {
          if (choice && choice.outcome === 'accepted') {
            resolve('accepted');
          } else {
            resolve('dismissed');
          }
        }).catch(function (err) {
          reject(err);
        });
      });
    }
  };
})(typeof window !== 'undefined' ? window : this);
