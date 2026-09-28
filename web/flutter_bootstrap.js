// Загрузчик веб-версии (шаблон Flutter). CanvasKit и запасные шрифты — со
// своего сервера (сборка с --no-web-resources-cdn): страница не обращается
// к серверам Google.
{{flutter_js}}
{{flutter_build_config}}

const kfhConfig = {
  canvasKitBaseUrl: "canvaskit/",
  // Своих запасных шрифтов нет: символ вне Roboto покажется квадратиком,
  // а не будет загружен с fonts.gstatic.com.
  fontFallbackBaseUrl: "fonts/fallback/",
};

_flutter.loader.load({
  config: kfhConfig,
  onEntrypointLoaded: async function (engineInitializer) {
    // Со своим onEntrypointLoaded настройки движку передаются здесь.
    const appRunner = await engineInitializer.initializeEngine(kfhConfig);
    document.getElementById("loading")?.remove();
    await appRunner.runApp();
  },
});
