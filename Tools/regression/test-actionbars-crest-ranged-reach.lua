-- test-actionbars-crest-ranged-reach.lua: a hunter's, mage's and warlock's break-out crest pieces (the rings round the whole crest aside), every one lit, keep their drawn pixels (alpha at least a quarter, read from each texture) off the action slots and the level badge and inside the crest's column, in hub units against the action slots and the badge as the HUD scene's own layout places them at 1920x1080, 2560x1440, 5120x1440 and 3840x2160 (the slots are the same for every class, so the hunter's stand in), measured as the render harness places them.
local Png = dofile("Tools/regression/png.lua")
local Scene = dofile("Tools/render/scene.lua")
local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local RING = { rim = true, cooldowns = true }

local CONTENT = {}
local function Content(path)
	if CONTENT[path] == nil then
		local file = tostring(path):gsub("\\", "/"):match("Media/.+$")
		local ok, alpha, w, h = pcall(Png.Alpha, file or "")
		local l, r, t, b = 1, 0, 1, 0
		for y = 0, ok and h - 1 or -1 do
			for x = 0, w - 1 do
				if alpha(x, y) >= 64 then
					l, r, t, b = math.min(l, x / w), math.max(r, (x + 1) / w), math.min(t, y / h), math.max(b, (y + 1) / h)
				end
			end
		end
		CONTENT[path] = ok and r > l and { l, r, t, b } or false
	end
	return CONTENT[path]
end

-- Alpha(region) -> the alpha it draws at, through its parents; a flare waiting at 0 draws nothing.
local function Alpha(region)
	local a = 1
	while region do
		a = a * (region:GetAlpha() or 1)
		region = region:GetParent()
	end
	return a
end

_G.RENDER_SCENE_LIB, _G.RENDER_TRACKERS = true, "lit"
local drawn, slots = {}, {}
for n, size in ipairs(SIZES) do
	_G.RENDER_SCREEN = { width = size[1], height = size[2], size = "auto" }
	local Hud = dofile("Tools/render/scenes/hud.lua")
	for _, class in ipairs(n == 1 and { "HUNTER", "MAGE", "WARLOCK" } or { "HUNTER" }) do
		local _, ns = Hud.Module("actionbars", Hud.Options({ layout = "DPS", class = class, applyPreset = true }))
		local solver = Scene.RectSolver(ns.Slab.hub._env)
		local hub = solver:rect(ns.Slab.hub)
		local cx, cy, unit = (hub[1] + hub[3]) / 2, (hub[2] + hub[4]) / 2, (hub[3] - hub[1]) / ns.Slab.RING
		local function Units(l, b, r, t)
			return { (l - cx) / unit, (b - cy) / unit, (r - cx) / unit, (t - cy) / unit }
		end
		if class == "HUNTER" then
			local avoid = { Units(unpack(solver:rect(ns.Slab.hub.plaque))) }
			for _, bar in pairs(ns.bars) do
				for _, button in ipairs(bar.buttons or {}) do
					if button:IsVisible() then avoid[#avoid + 1] = Units(unpack(solver:rect(button))) end
				end
			end
			assert(#avoid > 12, size[1] .. "x" .. size[2] .. ": the action slots and the level badge are placed")
			slots[size[1] .. "x" .. size[2]] = avoid
		end
		if n == 1 then
			for _, p in pairs(ns.SlabTrackers.state.form.pieces) do
				for _, part in ipairs(p:IsVisible() and not RING[p.spec.seat] and p.parts or {}) do
					local texture = part:IsVisible() and Alpha(part) > 0 and (part._barTexture or part)._state.Texture
					local box, content = solver:rect(part), texture and Content(texture[1])
					if box and content then
						local w, h = box[3] - box[1], box[4] - box[2]
						local area = Units(box[1] + content[1] * w, box[4] - content[4] * h, box[1] + content[2] * w, box[4] - content[3] * h)
						area.name = class .. " " .. p.spec.key .. "'s " .. tostring(texture[1]):match("[^\\/]+$")
						drawn[#drawn + 1] = area
					end
				end
			end
		end
	end
end
assert(#drawn > 40, "the lit pieces are measured (" .. #drawn .. ")")
for at, avoid in pairs(slots) do
	for _, d in ipairs(drawn) do
		assert(math.abs(d[1]) <= 80 and math.abs(d[3]) <= 80, d.name .. " stays inside the crest's column")
		for _, a in ipairs(avoid) do
			assert(d[3] <= a[1] or a[3] <= d[1] or d[4] <= a[2] or a[4] <= d[2], at .. ": " .. d.name .. " crosses an action slot or the level badge")
		end
	end
end
_G.RENDER_TRACKERS = nil

print("actionbars crest ranged reach ok")
