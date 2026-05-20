{{flutter_js}}
{{flutter_build_config}}

(function () {
  window.clinovaFlutterLoadFailed = function (err) {
    var errPanel = document.getElementById('clinova-startup-error');
    var loader = document.getElementById('clinova-startup-loader');
    if (loader) loader.style.display = 'none';
    if (errPanel) errPanel.hidden = false;
    if (window.console && console.error) {
      console.error('[Clinova] Flutter bootstrap failed', err);
    }
  };

  var loadPromise = _flutter.loader.load({
    onEntrypointLoaded: function (engineInitializer) {
      return engineInitializer
        .initializeEngine()
        .then(function (appRunner) {
          return appRunner.runApp();
        });
    },
  });

  if (loadPromise && typeof loadPromise.catch === 'function') {
    loadPromise.catch(window.clinovaFlutterLoadFailed);
  }
})();
