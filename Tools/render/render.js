// render.js: draw a scene JSON from Tools/render/scene.lua on a canvas, the way the game composites regions.
//
// window.renderScene(scene, options) -> Promise<HTMLCanvasElement>
//   options.ppu     pixels per screen unit (default 1.426)
//   options.canvas  the canvas to draw on (default: a new one appended to document.body)
//   options.base    URL prefix for relative file paths (default: the page's directory)
//   options.background  CSS colour behind the UI (default: a dark slate, so glass panels read)
//   options.backdrop    URL of an image drawn over the background, scaled to the canvas (the scenery)
//   options.backdropAlpha  the backdrop's opacity (default 1)
//
// A texture is drawn from its texcoords (4 or 8 values), tinted by multiplying with its vertex colour, then
// masked, then composited with its alpha; ADD becomes "lighter". Rect edges snap to whole device pixels,
// as the game snaps regions to physical pixels.

(function () {
	"use strict";

	const DEFAULT_PPU = 1.426;
	const FONT_FAMILIES = {};

	function basename(path) {
		return path.replace(/\\/g, "/").split("/").pop();
	}

	function familyFor(file) {
		const name = basename(file).replace(/\.[^.]+$/, "");
		if (!FONT_FAMILIES[name]) {
			FONT_FAMILIES[name] = "scene-" + name.replace(/[^A-Za-z0-9_-]/g, "_");
		}
		return FONT_FAMILIES[name];
	}

	function url(base, file) {
		if (/^(file|https?|data):/.test(file) || file.startsWith("/")) {
			return file.startsWith("/") ? "file://" + file : file;
		}
		return base + file;
	}

	const imageCache = {};

	function loadImage(src) {
		if (!imageCache[src]) {
			imageCache[src] = new Promise((resolve) => {
				const img = new Image();
				img.onload = () => resolve(img);
				img.onerror = () => {
					console.warn("image failed: " + src);
					resolve(null);
				};
				img.src = src;
			});
		}
		return imageCache[src];
	}

	const fontsLoaded = {};

	async function loadFont(base, file) {
		const family = familyFor(file);
		if (!fontsLoaded[file]) {
			fontsLoaded[file] = (async () => {
				try {
					const face = new FontFace(family, "url(" + url(base, file) + ")");
					await face.load();
					document.fonts.add(face);
				} catch (e) {
					console.warn("font failed: " + file + " " + e);
				}
			})();
		}
		await fontsLoaded[file];
		return family;
	}

	function rgba(c, alphaScale) {
		const a = (c.length > 3 ? c[3] : 1) * (alphaScale === undefined ? 1 : alphaScale);
		return "rgba(" + Math.round(c[0] * 255) + "," + Math.round(c[1] * 255) + "," + Math.round(c[2] * 255) + "," + a + ")";
	}

	// Edges snap to device pixels. A region at least half a pixel wide keeps one pixel, as the game's
	// hairlines do; a region thinner than that, such as an empty bar's fill, has no area and is skipped.
	function snapRect(rect, ppu) {
		const x0 = Math.round(rect[0] * ppu);
		const y0 = Math.round(rect[1] * ppu);
		const x1 = Math.round((rect[0] + rect[2]) * ppu);
		const y1 = Math.round((rect[1] + rect[3]) * ppu);
		const w = rect[2] * ppu >= 0.5 ? Math.max(1, x1 - x0) : 0;
		const h = rect[3] * ppu >= 0.5 ? Math.max(1, y1 - y0) : 0;
		return { x: x0, y: y0, w: w, h: h };
	}

	function empty(dest) {
		return dest.w <= 0 || dest.h <= 0;
	}

	function texCoords(item) {
		const tc = item.texCoord;
		if (!tc) {
			return { ul: [0, 0], ll: [0, 1], ur: [1, 0], lr: [1, 1] };
		}
		if (tc.length >= 8) {
			return { ul: [tc[0], tc[1]], ll: [tc[2], tc[3]], ur: [tc[4], tc[5]], lr: [tc[6], tc[7]] };
		}
		const l = tc[0], r = tc[1], t = tc[2], b = tc[3];
		return { ul: [l, t], ll: [l, b], ur: [r, t], lr: [r, b] };
	}

	// An offscreen copy of the image's used area, tinted by the vertex colour and optionally desaturated.
	// Returns a canvas covering the image's full texel space so the texcoord transform stays simple.
	function tinted(img, color, desaturated) {
		const off = document.createElement("canvas");
		off.width = img.width;
		off.height = img.height;
		const ctx = off.getContext("2d");
		if (desaturated) {
			ctx.filter = "grayscale(100%)";
		}
		ctx.drawImage(img, 0, 0);
		ctx.filter = "none";
		const needsTint = color[0] !== 1 || color[1] !== 1 || color[2] !== 1;
		if (needsTint) {
			ctx.globalCompositeOperation = "multiply";
			ctx.fillStyle = rgba([color[0], color[1], color[2], 1]);
			ctx.fillRect(0, 0, off.width, off.height);
			ctx.globalCompositeOperation = "destination-in";
			ctx.drawImage(img, 0, 0);
			ctx.globalCompositeOperation = "source-over";
		}
		return off;
	}

	// Draw the texel quad (ul, ll, ur) of source onto the destination rect through an affine transform.
	function drawQuad(ctx, source, coords, dest, rotation) {
		const sw = source.width, sh = source.height;
		const ulx = coords.ul[0] * sw, uly = coords.ul[1] * sh;
		const llx = coords.ll[0] * sw, lly = coords.ll[1] * sh;
		const urx = coords.ur[0] * sw, ury = coords.ur[1] * sh;
		// Texel-space basis: right = ur - ul, down = ll - ul.
		const rx = urx - ulx, ry = ury - uly;
		const dx = llx - ulx, dy = lly - uly;
		const det = rx * dy - ry * dx;
		if (Math.abs(det) < 1e-9) {
			// A mapping that samples one column or row of the texture (the chamfer diagonals read a column of
			// Line.png) has no inverse, so sample it per pixel instead.
			drawQuadSampled(ctx, source, coords, dest, rotation);
			return;
		}
		// Inverse: texel -> unit square (u along right, v along down).
		const iu = [dy / det, -dx / det];
		const iv = [-ry / det, rx / det];
		// unit -> dest: x = dest.x + u * dest.w, y = dest.y + v * dest.h.
		// Compose: texel (tx, ty) -> u = iu.(t - ul), v = iv.(t - ul).
		const a = iu[0] * dest.w, b = iv[0] * dest.h;
		const c = iu[1] * dest.w, d = iv[1] * dest.h;
		const e = dest.x - (a * ulx + c * uly);
		const f = dest.y - (b * ulx + d * uly);
		ctx.save();
		ctx.beginPath();
		ctx.rect(dest.x, dest.y, dest.w, dest.h);
		ctx.clip();
		if (rotation) {
			ctx.translate(dest.x + dest.w / 2, dest.y + dest.h / 2);
			ctx.rotate(-rotation);
			ctx.translate(-(dest.x + dest.w / 2), -(dest.y + dest.h / 2));
		}
		ctx.transform(a, b, c, d, e, f);
		ctx.imageSmoothingEnabled = true;
		ctx.imageSmoothingQuality = "high";
		ctx.drawImage(source, 0, 0);
		ctx.restore();
	}

	const sampleCache = new WeakMap();

	function pixelsOf(source) {
		let data = sampleCache.get(source);
		if (!data) {
			data = source.getContext("2d").getImageData(0, 0, source.width, source.height);
			sampleCache.set(source, data);
		}
		return data;
	}

	// Bilinear sample of a texel-space point, clamped to the edge as CLAMP does.
	function sample(data, tx, ty, out) {
		const w = data.width, h = data.height, px = data.data;
		const x = Math.min(Math.max(tx - 0.5, 0), w - 1);
		const y = Math.min(Math.max(ty - 0.5, 0), h - 1);
		const x0 = Math.floor(x), y0 = Math.floor(y);
		const x1 = Math.min(x0 + 1, w - 1), y1 = Math.min(y0 + 1, h - 1);
		const fx = x - x0, fy = y - y0;
		for (let c = 0; c < 4; c++) {
			const a = px[(y0 * w + x0) * 4 + c], b = px[(y0 * w + x1) * 4 + c];
			const d = px[(y1 * w + x0) * 4 + c], e = px[(y1 * w + x1) * 4 + c];
			out[c] = (a * (1 - fx) + b * fx) * (1 - fy) + (d * (1 - fx) + e * fx) * fy;
		}
	}

	// Each destination pixel maps to texel space through the parallelogram UL, UR, LL, whatever its shape.
	function drawQuadSampled(ctx, source, coords, dest, rotation) {
		const sw = source.width, sh = source.height;
		const ul = [coords.ul[0] * sw, coords.ul[1] * sh];
		const right = [coords.ur[0] * sw - ul[0], coords.ur[1] * sh - ul[1]];
		const down = [coords.ll[0] * sw - ul[0], coords.ll[1] * sh - ul[1]];
		const data = pixelsOf(source);
		const out = ctx.createImageData(dest.w, dest.h);
		const texel = [0, 0, 0, 0];
		for (let y = 0; y < dest.h; y++) {
			const v = (y + 0.5) / dest.h;
			for (let x = 0; x < dest.w; x++) {
				const u = (x + 0.5) / dest.w;
				const tx = ul[0] + right[0] * u + down[0] * v;
				const ty = ul[1] + right[1] * u + down[1] * v;
				sample(data, tx, ty, texel);
				const i = (y * dest.w + x) * 4;
				out.data[i] = texel[0];
				out.data[i + 1] = texel[1];
				out.data[i + 2] = texel[2];
				out.data[i + 3] = texel[3];
			}
		}
		const piece = document.createElement("canvas");
		piece.width = dest.w;
		piece.height = dest.h;
		piece.getContext("2d").putImageData(out, 0, 0);
		ctx.save();
		if (rotation) {
			ctx.translate(dest.x + dest.w / 2, dest.y + dest.h / 2);
			ctx.rotate(-rotation);
			ctx.translate(-(dest.x + dest.w / 2), -(dest.y + dest.h / 2));
		}
		ctx.drawImage(piece, dest.x, dest.y);
		ctx.restore();
	}

	function drawTiled(ctx, source, dest, ppu, scaleUnits) {
		// A tiled texture repeats at its texel size, read in the region's units.
		const scale = ppu * scaleUnits;
		const off = document.createElement("canvas");
		off.width = Math.max(1, Math.round(source.width * scale));
		off.height = Math.max(1, Math.round(source.height * scale));
		off.getContext("2d").drawImage(source, 0, 0, off.width, off.height);
		const pattern = ctx.createPattern(off, "repeat");
		ctx.save();
		ctx.translate(dest.x, dest.y);
		ctx.fillStyle = pattern;
		ctx.fillRect(0, 0, dest.w, dest.h);
		ctx.restore();
	}

	async function applyMasks(layer, item, ppu, base, offset) {
		if (!item.masks) {
			return;
		}
		const ctx = layer.getContext("2d");
		for (const mask of item.masks) {
			if (!mask.file) {
				continue;
			}
			const img = await loadImage(url(base, mask.file));
			if (!img) {
				continue;
			}
			const r = snapRect(mask.rect, ppu);
			ctx.globalCompositeOperation = "destination-in";
			ctx.drawImage(img, r.x - offset.x, r.y - offset.y, r.w, r.h);
			ctx.globalCompositeOperation = "source-over";
		}
	}

	// mode "rgb": the stops' colours at full alpha, to multiply into a texture. mode "alpha": white at the
	// stops' alphas, to cut the texture's alpha with destination-in. No mode: the stops as they are.
	function gradientFill(ctx, item, dest, mode) {
		const g = item.gradient;
		const horizontal = (g.orientation || "HORIZONTAL").toUpperCase() === "HORIZONTAL";
		const grad = horizontal
			? ctx.createLinearGradient(dest.x, 0, dest.x + dest.w, 0)
			: ctx.createLinearGradient(0, dest.y + dest.h, 0, dest.y);
		const stop = (c) => {
			if (mode === "rgb") {
				return rgba([c[0], c[1], c[2], 1]);
			}
			if (mode === "alpha") {
				return rgba([1, 1, 1, c.length > 3 ? c[3] : 1]);
			}
			return rgba(c);
		};
		grad.addColorStop(0, stop(g.from));
		grad.addColorStop(1, stop(g.to));
		return grad;
	}

	async function drawTexture(ctx, item, ppu, base) {
		const dest = snapRect(item.rect, ppu);
		if (empty(dest)) {
			return;
		}
		const vertex = item.vertex || [1, 1, 1, 1];
		const alpha = item.alpha * (vertex.length > 3 ? vertex[3] : 1);
		if (alpha <= 0) {
			return;
		}
		// Layer: the texture drawn at full opacity, then masked, then composited with its alpha and blend.
		const pad = 1;
		const layer = document.createElement("canvas");
		layer.width = dest.w + pad * 2;
		layer.height = dest.h + pad * 2;
		const lctx = layer.getContext("2d");
		const local = { x: pad, y: pad, w: dest.w, h: dest.h };
		const offset = { x: dest.x - pad, y: dest.y - pad };
		let drawn = false;
		if (item.file) {
			const img = await loadImage(url(base, item.file));
			if (img) {
				const source = tinted(img, item.color ? [item.color[0] * vertex[0], item.color[1] * vertex[1], item.color[2] * vertex[2]] : vertex, item.desaturated);
				if (item.tile && (item.tile[0] || item.tile[1])) {
					drawTiled(lctx, source, local, ppu, 1);
				} else {
					drawQuad(lctx, source, texCoords(item), local, item.rotation || 0);
				}
				drawn = true;
			}
		}
		if (!drawn) {
			let color = item.color || (item.atlas || item.missing ? [0.5, 0.5, 0.5, 0.6] : null);
			if (!color && item.fileID) {
				color = [0.35, 0.3, 0.25, 1];
			}
			if (color) {
				lctx.fillStyle = rgba([color[0] * vertex[0], color[1] * vertex[1], color[2] * vertex[2], color.length > 3 ? color[3] : 1]);
				lctx.fillRect(local.x, local.y, local.w, local.h);
				drawn = true;
			}
		}
		if (item.gradient) {
			if (drawn) {
				// Multiply the stops' colours into the texture, then cut its alpha by the stops' alphas.
				lctx.globalCompositeOperation = "multiply";
				lctx.fillStyle = gradientFill(lctx, item, local, "rgb");
				lctx.fillRect(local.x, local.y, local.w, local.h);
				lctx.globalCompositeOperation = "destination-in";
				lctx.fillStyle = gradientFill(lctx, item, local, "alpha");
				lctx.fillRect(local.x, local.y, local.w, local.h);
			} else {
				lctx.fillStyle = gradientFill(lctx, item, local);
				lctx.fillRect(local.x, local.y, local.w, local.h);
			}
			lctx.globalCompositeOperation = "source-over";
			drawn = true;
		}
		if (!drawn) {
			return;
		}
		await applyMasks(layer, item, ppu, base, offset);
		ctx.save();
		ctx.globalAlpha = Math.min(1, alpha);
		ctx.globalCompositeOperation = item.blend === "ADD" ? "lighter" : "source-over";
		ctx.drawImage(layer, offset.x, offset.y);
		ctx.restore();
	}

	function wrapLines(ctx, text, maxWidth) {
		const paragraphs = text.split("\n");
		const lines = [];
		for (const paragraph of paragraphs) {
			const words = paragraph.split(" ");
			let line = "";
			for (const word of words) {
				const candidate = line ? line + " " + word : word;
				if (line && ctx.measureText(candidate).width > maxWidth) {
					lines.push(line);
					line = word;
				} else {
					line = candidate;
				}
			}
			lines.push(line);
		}
		return lines;
	}

	// WoW's inline codes: |cAARRGGBB colour, |r reset, |H...|h link start, |h link end, |T...|t texture, || bar.
	function parseRuns(text, color) {
		const runs = [];
		let i = 0, current = color, buffer = "";
		const flush = () => {
			if (buffer) {
				runs.push({ text: buffer, color: current });
				buffer = "";
			}
		};
		while (i < text.length) {
			const ch = text[i];
			if (ch === "|" && i + 1 < text.length) {
				const code = text[i + 1];
				if (code === "|") {
					buffer += "|";
					i += 2;
					continue;
				}
				if (code === "c" && i + 10 <= text.length) {
					flush();
					const hex = text.substr(i + 2, 8);
					current = [parseInt(hex.substr(2, 2), 16) / 255, parseInt(hex.substr(4, 2), 16) / 255, parseInt(hex.substr(6, 2), 16) / 255, color[3]];
					i += 10;
					continue;
				}
				if (code === "r") {
					flush();
					current = color;
					i += 2;
					continue;
				}
				if (code === "H") {
					const end = text.indexOf("|h", i + 2);
					i = end < 0 ? text.length : end + 2;
					continue;
				}
				if (code === "h") {
					i += 2;
					continue;
				}
				if (code === "T" || code === "A") {
					const end = text.indexOf(code === "T" ? "|t" : "|a", i + 2);
					i = end < 0 ? text.length : end + 2;
					continue;
				}
				if (code === "n") {
					buffer += "\n";
					i += 2;
					continue;
				}
			}
			buffer += ch;
			i++;
		}
		flush();
		return runs;
	}

	function plainText(text) {
		return parseRuns(text, [1, 1, 1, 1]).map((run) => run.text).join("");
	}

	function fillRuns(ctx, runs, x, y, align, outline, shadow, ppu) {
		const total = runs.reduce((sum, run) => sum + ctx.measureText(run.text).width, 0);
		let start = x;
		if (align === "center") {
			start = x - total / 2;
		} else if (align === "right") {
			start = x - total;
		}
		ctx.textAlign = "left";
		for (const run of runs) {
			if (shadow) {
				ctx.fillStyle = rgba(shadow.color);
				ctx.fillText(run.text, start + shadow.offset[0] * ppu, y + shadow.offset[1] * ppu);
			}
			if (outline) {
				ctx.strokeText(run.text, start, y);
			}
			ctx.fillStyle = rgba(run.color);
			ctx.fillText(run.text, start, y);
			start += ctx.measureText(run.text).width;
		}
	}

	async function drawText(ctx, item, ppu, base) {
		const alpha = item.alpha;
		if (alpha <= 0 || !item.text) {
			return;
		}
		const sizePx = item.font.size * ppu;
		let family = "sans-serif";
		if (item.font.file) {
			family = await loadFont(base, item.font.file);
		} else {
			family = "Source Sans 3, sans-serif";
		}
		ctx.save();
		ctx.font = sizePx.toFixed(2) + "px " + family;
		ctx.textBaseline = "alphabetic";
		const rect = item.rect.slice();
		const plain = plainText(item.text);
		const measured = ctx.measureText(plain).width / ppu;
		const lineHeight = item.font.size * 1.2;
		// A text with no width of its own keeps the side its anchor fixed and takes the measured width.
		if (item.natural && item.natural.width) {
			const side = item.natural.width;
			if (side === "right") {
				rect[0] = rect[0] + rect[2] - measured;
			} else if (side === "center") {
				rect[0] = rect[0] + rect[2] / 2 - measured / 2;
			}
			rect[2] = measured;
		}
		// Wrap first: a text with a width but no height of its own is as tall as its wrapped lines.
		const canWrap = item.wordWrap !== false && !(item.natural && item.natural.width) && rect[2] * ppu > 0;
		const lines = canWrap ? wrapLines(ctx, plain, rect[2] * ppu) : plain.split("\n");
		if (item.natural && item.natural.height) {
			const side = item.natural.height;
			const block = lineHeight * lines.length;
			if (side === "bottom") {
				rect[1] = rect[1] + rect[3] - block;
			} else if (side === "middle") {
				rect[1] = rect[1] + rect[3] / 2 - block / 2;
			}
			rect[3] = block;
		}
		const dest = { x: rect[0] * ppu, y: rect[1] * ppu, w: rect[2] * ppu, h: rect[3] * ppu };
		// Colour runs follow the plain text: a wrapped line takes the runs that cover its characters.
		const runsAll = parseRuns(item.text, item.color);
		let cursor = 0;
		const lineRuns = lines.map((line) => {
			const runs = [];
			let need = line.length;
			while (need > 0 && cursor < plain.length) {
				let run = null, offset = 0, consumed = 0;
				for (const r of runsAll) {
					if (cursor < consumed + r.text.length) {
						run = r;
						offset = cursor - consumed;
						break;
					}
					consumed += r.text.length;
				}
				if (!run) {
					break;
				}
				const take = Math.min(need, run.text.length - offset);
				runs.push({ text: run.text.substr(offset, take), color: run.color });
				cursor += take;
				need -= take;
			}
			if (plain[cursor] === " " || plain[cursor] === "\n") {
				cursor++;
			}
			return runs.length ? runs : [{ text: line, color: item.color }];
		});
		const lh = lineHeight * ppu;
		let align = "left";
		let x = dest.x;
		if (item.justifyH === "CENTER") {
			align = "center";
			x = dest.x + dest.w / 2;
		} else if (item.justifyH === "RIGHT") {
			align = "right";
			x = dest.x + dest.w;
		}
		ctx.textAlign = align;
		const block = lines.length * lh;
		let top = dest.y;
		if (item.justifyV === "MIDDLE") {
			top = dest.y + (dest.h - block) / 2;
		} else if (item.justifyV === "BOTTOM") {
			top = dest.y + dest.h - block;
		}
		// Baseline sits about 0.78 em under the line's top for the kit's faces.
		const ascent = sizePx * 0.78 + (lh - sizePx) / 2;
		ctx.globalAlpha = Math.min(1, alpha);
		const outline = /OUTLINE/.test(item.font.flags || "");
		if (outline) {
			ctx.lineWidth = /THICK/.test(item.font.flags) ? 2 : 1;
			ctx.strokeStyle = "rgba(0,0,0,1)";
			ctx.lineJoin = "round";
		}
		for (let i = 0; i < lines.length; i++) {
			const y = top + i * lh + ascent;
			fillRuns(ctx, lineRuns[i], Math.round(x), Math.round(y), align, outline, item.shadow, ppu);
		}
		ctx.restore();
	}

	async function drawSwipe(ctx, item, ppu, base) {
		const dest = snapRect(item.rect, ppu);
		if (empty(dest)) {
			return;
		}
		const layer = document.createElement("canvas");
		layer.width = dest.w;
		layer.height = dest.h;
		const lctx = layer.getContext("2d");
		const cx = dest.w / 2, cy = dest.h / 2;
		const radius = Math.hypot(dest.w, dest.h);
		// The dark part is what is still on cooldown. It starts at 12 o'clock and unwinds clockwise, so the
		// remaining sector runs from the current hand back to 12 o'clock.
		const remaining = item.fraction;
		const start = -Math.PI / 2;
		let from, to;
		if (item.reverse) {
			from = start;
			to = start + Math.PI * 2 * remaining;
		} else {
			from = start + Math.PI * 2 * (1 - remaining);
			to = start + Math.PI * 2;
		}
		lctx.fillStyle = rgba(item.color);
		lctx.beginPath();
		lctx.moveTo(cx, cy);
		lctx.arc(cx, cy, radius, from, to, false);
		lctx.closePath();
		lctx.fill();
		if (item.file) {
			const img = await loadImage(url(base, item.file));
			if (img) {
				lctx.globalCompositeOperation = "destination-in";
				lctx.drawImage(img, 0, 0, dest.w, dest.h);
				lctx.globalCompositeOperation = "source-over";
			}
		}
		ctx.save();
		ctx.globalAlpha = Math.min(1, item.alpha);
		ctx.drawImage(layer, dest.x, dest.y);
		ctx.restore();
		if (item.countdown) {
			await drawText(ctx, {
				kind: "text", alpha: item.alpha, text: item.countdown, rect: item.rect,
				font: item.font || { size: 12, flags: "OUTLINE" }, color: [1, 1, 1, 1], justifyH: "CENTER", justifyV: "MIDDLE",
			}, ppu, base);
		}
	}

	async function renderScene(scene, options) {
		options = options || {};
		const ppu = options.ppu || DEFAULT_PPU;
		const base = options.base !== undefined ? options.base : document.baseURI.replace(/[^/]*$/, "");
		const canvas = options.canvas || document.createElement("canvas");
		canvas.width = Math.round(scene.screen.width * ppu);
		canvas.height = Math.round(scene.screen.height * ppu);
		if (!options.canvas) {
			document.body.appendChild(canvas);
		}
		const ctx = canvas.getContext("2d");
		ctx.fillStyle = options.background || "#1e2a38";
		ctx.fillRect(0, 0, canvas.width, canvas.height);
		if (options.backdrop) {
			const img = await loadImage(options.backdrop);
			if (img) {
				ctx.save();
				ctx.globalAlpha = options.backdropAlpha === undefined ? 1 : Math.max(0, Math.min(1, options.backdropAlpha));
				ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
				ctx.restore();
			}
		}
		for (const item of scene.items) {
			if (options.filter && !options.filter(item)) {
				continue;
			}
			// An item under a frame that clips its children draws only inside that frame's rect.
			if (item.clip) {
				const c = snapRect(item.clip, ppu);
				ctx.save();
				ctx.beginPath();
				ctx.rect(c.x, c.y, c.w, c.h);
				ctx.clip();
			}
			if (item.kind === "texture") {
				await drawTexture(ctx, item, ppu, base);
			} else if (item.kind === "text") {
				await drawText(ctx, item, ppu, base);
			} else if (item.kind === "swipe") {
				await drawSwipe(ctx, item, ppu, base);
			}
			if (item.clip) {
				ctx.restore();
			}
		}
		return canvas;
	}

	window.renderScene = renderScene;
})();
