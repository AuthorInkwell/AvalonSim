(function () {
	"use strict";

	if (window.crossOriginIsolated || !("serviceWorker" in navigator)) {
		return;
	}

	let reloading = false;
	navigator.serviceWorker.addEventListener("controllerchange", function () {
		if (!reloading) {
			reloading = true;
			window.location.reload();
		}
	});

	navigator.serviceWorker.register("index.service.worker.js", { scope: "./" })
		.then(function (registration) {
			registration.update();
			if (registration.active && !navigator.serviceWorker.controller) {
				window.location.reload();
			}
		})
		.catch(function (error) {
			console.error("Unable to enable browser isolation for Avalon:", error);
		});
}());
