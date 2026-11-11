-- band_ink_lib.lua: Run(size) builds the unit frames at Full on nine screens at one Interface size and fails when the portrait band is resampled, covers a drawn pixel of the gilt ring, its disc or the portrait, or draws above the level badge.
local Hud = dofile("Tools/render/scenes/hud.lua")
local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
local M = {}
local cases, closest = 0, math.huge

local function within(object, frames)
	while object do
		for _, frame in ipairs(frames) do
			if object == frame then return true end
		end
		object = type(object.GetParent) == "function" and object:GetParent() or nil
	end
	return false
end

local function run(screen, size)
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 768 / 1080, size = size or nil })
	local opts = { class = "PALADIN", layout = "DPS", applyPreset = true, settings = Hud.PresetSettings("DPS"),
		target = { name = "Shadowgale Poacher", creature = "Humanoid", classification = "elite", power = 240, powerMax = 345 } }
	local scene, U = Hud.Module("unitframes", opts)
	local K = Hud.envs[scene].KstyleUI
	local ASSETS, INK = K.Widgets.OrnamentAssets, K.Widgets.OrnamentInk
	local pixels = screen[2] / 1080
	local drawn = {}
	for i, item in ipairs(scene.items) do drawn[item.object] = i end
	for _, kind in ipairs({ "player", "target" }) do
		local label = string.format("%dx%d size %s %s", screen[1], screen[2], tostring(size or "shipped"), kind)
		local view = U.Frames.Get(kind).views[1]
		local handle = view.portraitOrnament
		assert(handle.used >= 1, label .. ": the band is drawn at Full")
		local index = assert(drawn[handle.textures[1]], label .. ": the band is painted")
		local band = scene.items[index]
		local name = assert(band.file:match("(Ring%d+)%.png$"), label .. ": the first portrait piece is the band")
		local spec = ASSETS[name]
		local x, y, w, h = band.rect[1] * pixels, band.rect[2] * pixels, band.rect[3] * pixels, band.rect[4] * pixels
		local uv = band.texCoord
		local function whole(v) return math.abs(v - math.floor(v + 0.5)) < 1e-3 end
		local exact = whole(x) and whole(y) and whole(w) and whole(h)
			and math.abs(math.abs(uv[2] - uv[1]) * spec[3] - math.floor(w + 0.5)) < 1e-6 and math.abs(math.abs(uv[4] - uv[3]) * spec[4] - math.floor(h + 0.5)) < 1e-6
		assert(exact, string.format("%s: %s samples %.6f x %.6f texels into %.4f x %.4f px at %.4f,%.4f, so it is resampled", label, name,
			math.abs(uv[2] - uv[1]) * spec[3], math.abs(uv[4] - uv[3]) * spec[4], w, h, x, y))
		local bx, by = x + w / 2, y + h / 2
		local hole, outer = INK.holes[name] * spec[1] / 2, INK.circles[name] * spec[1] / 2
		local content, reach = {}, 0
		for _, entry in ipairs({ { view.ring, "RingBevel" }, { view.portraitBack, "Dot" }, { view.portrait } }) do
			local item = scene.items[assert(drawn[entry[1]], label .. ": the portrait part is painted")]
			local r = item.rect
			local cw = r[3] * pixels
			local radius = (entry[2] and INK.circles[entry[2]] or 1) * cw / 2 + 1
			content[#content + 1] = { (r[1] + r[3] / 2) * pixels, (r[2] + r[4] / 2) * pixels, radius }
			reach = math.max(reach, radius)
		end
		local covered = 0
		for py = math.floor(by - reach - 2), math.ceil(by + reach + 2) do
			for px = math.floor(bx - reach - 2), math.ceil(bx + reach + 2) do
				local cx, cy = px + 0.5, py + 0.5
				local d = math.sqrt((cx - bx) ^ 2 + (cy - by) ^ 2)
				if d >= hole and d <= outer then
					for _, c in ipairs(content) do
						if (cx - c[1]) ^ 2 + (cy - c[2]) ^ 2 <= c[3] ^ 2 then
							covered = covered + 1
							break
						end
					end
				end
			end
		end
		assert(covered == 0, string.format("%s: %s covers %d drawn pixels of the gilt ring, its disc or the portrait", label, name, covered))
		closest = math.min(closest, hole - reach)
		for i, item in ipairs(scene.items) do
			local object = item.object
			if object == view.levelText or within(object, { view.badge, view.disc }) then
				assert(i > index, label .. ": the level badge draws above the band: " .. tostring(item.file or item.text or item.kind))
			end
		end
		cases = cases + 1
	end
	collectgarbage("collect")
end

function M.Run(size)
	local old, oldLevel = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_ORNAMENTS")
	rawset(_G, "RENDER_ORNAMENTS", "Full")
	for _, screen in ipairs(SCREENS) do run(screen, size) end
	rawset(_G, "RENDER_SCREEN", old)
	rawset(_G, "RENDER_ORNAMENTS", oldLevel)
	print(string.format("ok the portrait band draws 1:1 and clear of the gilt ring in %d frames on nine screens at Interface size %s; the tightest band edge is %.2f px past the ring's ink", cases, tostring(size or "shipped"), closest))
end

return M
