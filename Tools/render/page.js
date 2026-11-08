// page.js: the page driver. Renders window.SCENE (or the JSON named by ?scene=) with window.RENDER_OPTIONS,
// then sets document.title to "rendered" so a screenshot knows the canvas is complete.
(async function () {
	"use strict";
	const params = new URLSearchParams(window.location.search);
	const options = Object.assign({}, window.RENDER_OPTIONS || {});
	if (!options.base) {
		// render.html lives in Tools/render/, so repository-relative asset paths start two folders up.
		options.base = new URL("../../", document.baseURI).href;
	}
	if (params.get("ppu")) {
		options.ppu = parseFloat(params.get("ppu"));
	}
	let scene = window.SCENE;
	if (!scene && params.get("scene")) {
		const response = await fetch(params.get("scene"));
		scene = await response.json();
	}
	if (!scene) {
		document.body.textContent = "No scene. Open render.html?scene=out/<name>.json&ppu=1.426 with --allow-file-access-from-files, or run Tools/render/shoot.sh.";
		return;
	}
	const status = document.getElementById("status");
	const errors = [];
	window.addEventListener("error", (event) => errors.push(String(event.message)));
	try {
		await window.renderScene(scene, options);
	} catch (e) {
		errors.push(String(e && e.stack || e));
	}
	window.RENDER_ERRORS = errors;
	if (errors.length) {
		console.error("render errors: " + errors.join(" | "));
		const note = document.createElement("div");
		note.id = "render-errors";
		note.textContent = errors.join("\n");
		document.body.appendChild(note);
	}
	if (status) {
		const skipped = scene.skipped || {};
		status.textContent = scene.items.length + " drawables, " + (scene.log || []).length + " log lines, skipped: hidden " +
			(skipped.hidden || 0) + ", transparent " + (skipped.transparent || 0) + ", unresolved " + (skipped.unresolved || 0);
	}
	document.title = "rendered";
	window.RENDER_DONE = true;
})();
