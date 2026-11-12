-- ornament_guard_lib.lua: require the Full centre ornaments and reject later ornament rectangles covering semantic regions.
local M = {}
local screens = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}

local EPS = 0.001

local function overlap(a, b)
	return a[1] < b[1] + b[3] - EPS and b[1] < a[1] + a[3] - EPS
		and a[2] < b[2] + b[4] - EPS and b[2] < a[2] + a[4] - EPS
end

local function assetName(item)
	return item.file and item.file:match("Media/Textures/ForgedOrnaments/([^/]+)%.png$")
end

function M.Expected(handle, assets, width, height, subtle)
	local w, h = width or handle.width, height or handle.height
	if handle.kind == "ring" then
		local side = math.min(w, h)
		if side < 24 or subtle then return {} end
		local ring = assets["Ring" .. side] and side or math.ceil(side / 2) * 2
		while ring > 24 and not assets["Ring" .. ring] do ring = ring - 1 end
		local names = { assets["Ring" .. ring] and "Ring" .. ring or nil }
		local hole = 80
		for _, n in ipairs({ 80, 70, 60, 52, 44, 38, 32, 28, 24, 20, 17, 14 }) do
			if n >= side / 2 + 1 then hole = n end
		end
		if handle.player then return names end
		local pendant = handle.boss and "BossPendantR" .. hole or handle.elite and "ElitePendantR" .. hole
		if pendant and assets[pendant] then names[#names + 1] = pendant end
		return names
	end
	assert(handle.kind == "bar", "unsupported test handle " .. tostring(handle.kind))
	return nil
end

function M.Check(items, handles, semantics, label, screen, assets, pixels)
	pixels = pixels or 1
	local drawn = {}
	for i, item in ipairs(items) do
		drawn[item.object] = i
	end
	for name, handle in pairs(handles) do
		assert(handle, label .. ": missing ornament handle " .. name)
		if handle.expected then
			assert(handle.used == #handle.expected, label .. ": " .. name .. " expected " .. #handle.expected .. " pieces, got " .. handle.used)
		elseif not handle.joined then
			assert(handle.used > 0, label .. ": missing Full ornament " .. name)
		end
		for i = 1, handle.used do
			local index = assert(drawn[handle.textures[i]], label .. ": missing painted ornament " .. name .. " #" .. i)
			local item = items[index]
			local rect = item.rect
			assert(item.file and item.file:find("Media/Textures/ForgedOrnaments/", 1, true), label .. ": wrong ornament texture " .. name)
			assert(not item.missing and item.object._shown ~= false and (item.alpha or 1) > 0, label .. ": hidden or missing ornament " .. name)
			if handle.expected then
				assert(assetName(item) == handle.expected[i], label .. ": " .. name .. " #" .. i .. " expected " .. tostring(handle.expected[i]) .. ", got " .. tostring(assetName(item)))
			end
			assert(rect and rect[3] > 0 and rect[4] > 0, label .. ": empty ornament " .. name)
			if assets then
				local spec = assert(assets[assetName(item)], label .. ": unknown asset " .. tostring(assetName(item)))
				for axis = 1, 4 do
					assert(type(spec[axis]) == "number" and spec[axis] > 0 and spec[axis] == math.floor(spec[axis]), label .. ": malformed native metadata")
				end
				local rail = assetName(item):find("^Rail%d+$") ~= nil
				local forge = assetName(item):find("^Forge%d+$") ~= nil
				assert((rail and rect[3] * pixels >= spec[1] - 0.001 or forge and rect[3] * pixels <= spec[1] + 0.001
					or math.abs(rect[3] * pixels - spec[1]) < 0.001)
					and math.abs(rect[4] * pixels - spec[2]) < 0.001,
					label .. ": stretched native art " .. name .. " " .. assetName(item))
				local uv = assert(item.texCoord, label .. ": missing native crop " .. name)
				assert(#uv == 4 and math.abs(math.abs(uv[2] - uv[1]) - (forge and math.floor(rect[3] * pixels + 0.5) or spec[1]) / spec[3]) < 1e-7
					and math.abs(math.abs(uv[4] - uv[3]) - spec[2] / spec[4]) < 1e-7,
					label .. ": stretched native crop " .. name)
				if rail or forge then
					assert(math.abs(rect[3] * pixels - math.floor(rect[3] * pixels + 0.5)) < 0.001, label .. ": fractional rail length " .. name)
				end
				for axis = 1, 2 do
					local coordinate = rect[axis] * pixels
					assert(math.abs(coordinate - math.floor(coordinate + 0.5)) < 0.001, label .. ": fractional physical origin " .. name)
				end
			end
			assert(rect[1] >= -0.001 and rect[2] >= -0.001 and rect[1] + rect[3] <= screen[1] + 0.001
				and rect[2] + rect[4] <= screen[2] + 0.001, label .. ": ornament offscreen " .. name)
			for semantic, semanticName in pairs(semantics) do
				local si = drawn[semantic]
				if si and (index > si or semanticName:find("whiteCursor", 1, true)) and overlap(rect, items[si].rect) then
					error(string.format("%s: ornament %s %s [%.5f,%.5f,%.5f,%.5f] covers %s [%.5f,%.5f,%.5f,%.5f]", label, name, item.file,
						rect[1], rect[2], rect[3], rect[4], semanticName, unpack(items[si].rect)))
				end
			end
		end
		for i = handle.used + 1, #handle.textures do
			assert(not drawn[handle.textures[i]], label .. ": stale ornament remains painted " .. name .. " #" .. i)
		end
	end
	for semantic, name in pairs(semantics) do
		if name:find("whiteCursor", 1, true) then
			local item = items[assert(drawn[semantic], label .. ": white fill cursor is not painted " .. name)]
			local color = assert(item.color, label .. ": white fill cursor lost its colour")
			assert(color[1] == 1 and color[2] == 1 and color[3] == 1 and color[4] == 1, label .. ": fill cursor is not white")
		end
	end
end

function M.Run(layout, class, form, classification)
	local originalDo = dofile
	local function guardDo(path)
		local value = originalDo(path)
		if path == "Tools/render/scene.lua" then
			local build = value.Build
			function value.Build(env, opts)
				env._guardSceneOptions = opts
				env._guardSceneBuilder = build
				return build(env, opts)
			end
		end
		return value
	end
	rawset(_G, "dofile", guardDo)
	local Hud = dofile("Tools/render/scenes/hud.lua")
	local Scene = dofile("Tools/render/scene.lua")
	local old, oldLevel = rawget(_G, "RENDER_SCREEN"), rawget(_G, "RENDER_ORNAMENTS")
	for _, level in ipairs({ "Full", "Subtle" }) do
		rawset(_G, "RENDER_ORNAMENTS", level)
		for _, screen in ipairs(screens) do
			rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2] })
			local opts = { class = class, layout = layout, applyPreset = true, settings = Hud.PresetSettings(layout),
				target = { name = "Shadowgale Poacher", creature = "Humanoid", classification = classification or "elite", power = 240, powerMax = 345 },
				targetAuras = { { 135813, "9s" }, { 136026, "3s" } } }
			if class == "DRUID" then
				opts.player = { powerType = form == "cat" and 3 or 1, powerToken = form == "cat" and "ENERGY" or "RAGE",
					power = 60, powerMax = 100, powers = { [0] = 2200 }, powerMaxes = { [0] = 4000 } }
				opts.spec = { combo = 3 }
			elseif class == "ROGUE" then
				opts.spec = { cast = { "First Aid", 135966, 746, 8 } }
			end
			local scene, U = Hud.Module("unitframes", opts)
			local handles, semantics = {}, {}
			for _, kind in ipairs({ "player", "target" }) do
				local view = U.Frames.Get(kind).views[1]
				local cast = kind == "player" and U.CastBars.Get(kind)[1] or U.CastBars.Inline(kind)[1]
				assert(view.portraitOrnament.player == (kind == "player"), kind .. ": portrait player identity")
				if kind == "target" then
					assert(view.portraitOrnament.boss == (classification == "worldboss"), "target portrait boss classification")
					assert(view.portraitOrnament.elite == (classification ~= "normal"), "target portrait elite classification")
				end
				for _, entry in ipairs({ { "health", view.health.ornament }, { "portrait", view.portraitOrnament },
					{ "cast", cast.ornament } }) do
					handles[kind .. "." .. entry[1]] = assert(entry[2], kind .. ": missing " .. entry[1] .. " handle")
				end
				for name, object in pairs({ name = view.name, caption = view.caption, level = view.levelText,
					health = view.health._barTexture, power = view.power._barTexture, cast = cast.bar._barTexture,
					castText = cast.text, castTimer = cast.timer }) do
					semantics[object] = kind .. "." .. name
				end
				if kind == "player" then
					for name, bar in pairs({ health = view.health, power = view.power, cast = cast.bar }) do
						if name == "cast" then assert(bar.fillCursor, "player cast retains its fill cursor") end
						if bar.fillCursor then semantics[bar.fillCursor] = "player." .. name .. ".whiteCursor" end
					end
				end
			end
			local label = string.format("%s %s %s %s %dx%d", level, layout, class, form or "", screen[1], screen[2])
			local env = Hud.envs[scene]
			local K = env.KstyleUI
			assert(K.Widgets.Setting("ornaments") == level and K.Widgets.Setting("cardMaterial") == "ForgedBrackets", label .. ": forged setting active")
			local solver = Scene.RectSolver(env)
			for name, handle in pairs(handles) do
				if handle.bare then assert(handle.used == 0, label .. ": " .. name .. " draws around the unit frame's bars, which carry no ornament (Lee, 2026-11-12)") end
				if handle.joined or handle.bare then handles[name] = nil end
			end
			for name, handle in pairs(handles) do
				local _, _, w, h = Scene.RectIn(solver, handle.target)
				w, h = math.floor(w * screen[2] / 1080 + 0.5), math.floor(h * screen[2] / 1080 + 0.5)
				assert(handle.width == w and (handle.span or handle.spans or handle.height == h), label .. ": wrong physical target size " .. name)
				handle.expected = M.Expected(handle, K.Widgets.OrnamentAssets, w, (handle.span or handle.spans) and handle.height or h, level == "Subtle")
			end
			M.Check(scene.items, handles, semantics, label, { 1080 * screen[1] / screen[2], 1080 }, K.Widgets.OrnamentAssets, screen[2] / 1080)
			local function same(a, b)
				if type(a) ~= type(b) then return false end
				if type(a) ~= "table" then return a == b end
				for key, v in pairs(a) do if key ~= "object" and not same(v, b[key]) then return false end end
				for key in pairs(b) do if key ~= "object" and a[key] == nil then return false end end
				return true
			end
			local original = {}
			for _, item in ipairs(scene.items) do if not assetName(item) then original[item.object] = item end end
			K.Store.Module("Widgets").ornaments = "Off"
			for _, handle in ipairs(env._ornamentHandles) do handle:Restyle() end
			local off = env._guardSceneBuilder(env, env._guardSceneOptions)
			for _, item in ipairs(off.items) do
				assert(not assetName(item), label .. ": Off leaves ornament art visible")
				assert(original[item.object] and same(original[item.object], item), label .. ": unrelated drawable changed when ornaments switched Off: " .. tostring(item.text or item.file or item.kind))
				original[item.object] = nil
			end
			assert(next(original) == nil, label .. ": ornaments hid or removed an unrelated drawable")
			collectgarbage("collect")
		end
	end
	rawset(_G, "RENDER_SCREEN", old)
	rawset(_G, "RENDER_ORNAMENTS", oldLevel)
	rawset(_G, "dofile", originalDo)
	print("ok Full and Subtle ornaments " .. layout .. " " .. class .. " " .. (form or "") .. ": nine screens")
end

return M
