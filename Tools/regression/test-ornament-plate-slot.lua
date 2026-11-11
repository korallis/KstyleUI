-- test-ornament-plate-slot.lua: on a plate whose ends stand off its bars, the slot between the bars' rims, the top rail and an end is covered by track-colour fills down to the lowest bar, idle and casting, wherever no plate icon sits in it, no plate draws more than six pieces, and no fill covers a rail, an end or plate content.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local EPS = 0.001

local PLATES = {
	{ token = "nameplate1", x = 300, y = 220, unit = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true } },
	{ token = "nameplate2", x = 300, y = 400, unit = { name = "Riverglade Snapper", health = 1420, maxHealth = 1540, level = 37, reaction = 2, canAttack = true } },
	{ token = "nameplate3", x = 760, y = 220, unit = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, threat = 2, raid = 8 } },
	{ token = "nameplate4", x = 760, y = 400, unit = { name = "Onyxia", health = 900000, maxHealth = 1000000, level = -1, classification = "worldboss", reaction = 2, canAttack = true } },
	{ token = "nameplate5", x = 1220, y = 220, unit = { name = "Ashwing Rare", health = 4000, maxHealth = 5000, level = 41, classification = "rareelite", reaction = 2, canAttack = true, raid = 1 } },
}
local CASTS = {
	nameplate1 = { name = "Terrifying Screech", text = "Terrifying Screech", texture = 136124, notInterruptible = true },
	nameplate3 = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false },
	nameplate4 = { name = "Deep Breath", text = "Deep Breath", texture = 136124, notInterruptible = true },
	nameplate5 = { name = "Snap", text = "Snap", texture = 132200, notInterruptible = false },
}

local function overlap(a, b)
	return a[1] < b[1] + b[3] - EPS and b[1] < a[1] + a[3] - EPS and a[2] < b[2] + b[4] - EPS and b[2] < a[2] + a[4] - EPS
end

local function inside(x, y, r)
	return x > r[1] and x < r[1] + r[3] and y > r[2] and y < r[2] + r[4]
end

local function content(plate)
	local list = { plate.name, plate.healthText, plate.levelText, plate.level, plate.marker, plate.raid,
		plate.castName, plate.castTime, plate.castIcon, plate.castShield, plate.health, plate.castBar }
	for _, group in pairs(plate.auras and plate.auras._groups or {}) do
		for _, button in ipairs(group.frames or {}) do list[#list + 1] = button end
	end
	return list
end

local closed, open = 0, {}

local function check(env, ns, label, pixel)
	local scene = Scene.Build(env)
	local solver = Scene.RectSolver(env)
	local rects = {}
	for _, item in ipairs(scene.items) do rects[item.object] = item.rect end
	for _, spec in ipairs(PLATES) do
		local plate = ns.Plates.Get(spec.token)
		local handle = plate.ornament
		local fills, rails, ends, drawn = {}, {}, {}, 0
		for i = 1, handle.used do
			local texture = handle.textures[i]
			if texture:IsVisible() then
				drawn = drawn + 1
				local rect = assert(rects[texture], label .. ": " .. spec.token .. " ornament piece not drawn")
				local file = texture:GetTexture()
				local name = type(file) == "string" and file:match("([%w]+)%.png$")
				if not name then
					fills[#fills + 1] = rect
				elseif name:find("^Rail") or name:find("^Forge") then
					rails[#rails + 1] = rect
				elseif name:find("^End") then
					ends[#ends + 1] = rect
				end
			end
		end
		assert(drawn <= 6, label .. ": " .. spec.token .. " draws " .. drawn .. " ornament pieces, more than six")
		local blocks = {}
		for _, object in ipairs(content(plate)) do
			if object.IsVisible and object:IsVisible() then
				local x, y, w, h = Scene.RectIn(solver, object)
				if x and w > 0 and h > 0 then blocks[#blocks + 1] = { x, y, w, h } end
			end
		end
		for _, fill in ipairs(fills) do
			for _, piece in ipairs(rails) do assert(not overlap(fill, piece), label .. ": " .. spec.token .. " a fill covers a rail") end
			for _, piece in ipairs(ends) do assert(not overlap(fill, piece), label .. ": " .. spec.token .. " a fill covers an end") end
		end
		if #ends == 2 and #rails >= 2 then
			table.sort(ends, function(a, b) return a[1] < b[1] end)
			local tx, ty, tw, th = Scene.RectIn(solver, handle.target)
			local rim = (handle.target.rimOutset or 0) * tw / handle.target:GetWidth()
			local function snap(v) return math.floor(v / pixel + 0.5) * pixel end
			local barL, barR, barB = snap(tx - rim), snap(tx + tw + rim), snap(ty + th + rim)
			if plate.castBar and plate.castBar:IsVisible() then
				local _, cy, _, ch = Scene.RectIn(solver, plate.castBar)
				if cy then barB = math.max(barB, snap(cy + ch + (plate.castBar.rimOutset or 0) * tw / handle.target:GetWidth())) end
			end
			local top, bottom
			for _, rail in ipairs(rails) do
				if rail[1] < barR and rail[1] + rail[3] > barL then
					if not top or rail[2] < top[2] then top = rail end
					if not bottom or rail[2] > bottom[2] then bottom = rail end
				end
			end
			local y1, y2 = top[2] + top[4], math.min(bottom[2], barB)
			for side, span in ipairs({ { ends[1][1] + ends[1][3], barL }, { barR, ends[2][1] } }) do
				local slot = { span[1], y1, span[2] - span[1], y2 - y1 }
				if slot[3] >= pixel - EPS and slot[4] >= pixel - EPS then
					local busy = false
					for _, block in ipairs(blocks) do
						if overlap({ slot[1] - pixel, slot[2] - pixel, slot[3] + 2 * pixel, slot[4] + 2 * pixel }, block) then busy = true end
					end
					if not busy then
						local x = slot[1] + pixel / 2
						while x < slot[1] + slot[3] do
							local y = slot[2] + pixel / 2
							while y < slot[2] + slot[4] do
								local covered = false
								for _, fill in ipairs(fills) do
									if inside(x, y, fill) then covered = true break end
								end
								if not covered then
									open[#open + 1] = string.format("%s: %s %s slot [%.2f,%.2f,%.2f,%.2f] shows the backdrop at %.2f,%.2f",
										label, spec.token, side == 1 and "west" or "east", slot[1], slot[2], slot[3], slot[4], x, y)
									x, y = math.huge, math.huge
								end
								y = y + pixel
							end
							x = x + pixel
						end
						closed = closed + 1
					end
				end
			end
		end
		for _, fill in ipairs(fills) do
			for _, block in ipairs(blocks) do
				assert(not overlap(fill, block), string.format("%s: %s a fill [%.2f,%.2f,%.2f,%.2f] covers plate content [%.2f,%.2f,%.2f,%.2f]",
					label, spec.token, fill[1], fill[2], fill[3], fill[4], block[1], block[2], block[3], block[4]))
			end
		end
	end
end

local function run(width, height, scale, level, casting)
	local env, K, ns = N.New({ width = width, height = height, uiScale = 768 / 1080, size = "default" })
	env._textWidth = function(text, fontPath, size)
		return Scene.TextWidth(Scene.PlainText(text), size, fontPath)
	end
	local widgets = K.Store.Module("Widgets")
	widgets.cardMaterial, widgets.ornaments = "ForgedBrackets", level
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	env._time = 10
	for _, spec in ipairs(PLATES) do
		local base = N.Add(env, spec.token, spec.unit, { scale = scale })
		local k = 768 / 1080
		base:ClearAllPoints()
		base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", spec.x * k, (1080 - spec.y) * k)
	end
	if casting then
		for token, cast in pairs(CASTS) do N.Cast(env, token, cast) end
	end
	for _ = 1, 20 do N.Tick(env, 0.05) end
	env.RunTimers()
	Scene.Build(env)
	K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
	local label = string.format("%s %dx%d scale %.2f %s", level, width, height, scale, casting and "casting" or "idle")
	if casting then
		for token in pairs(CASTS) do assert(ns.Plates.Get(token).cast:IsShown(), label .. ": " .. token .. " shows its cast") end
	end
	check(env, ns, label, 1080 / height)
	assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
end

for _, screen in ipairs({ { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 }, { 3456, 2234 }, { 3840, 2160 } }) do
	for _, scale in ipairs({ 1, 0.58 }) do
		for _, level in ipairs({ "Subtle", "Full" }) do
			run(screen[1], screen[2], scale, level, false)
			run(screen[1], screen[2], scale, level, true)
		end
	end
end
assert(#open == 0, #open .. " open slots, first: " .. tostring(open[1]))
assert(closed >= 16, "the slot check ran on too few plate sides: " .. closed)
print(string.format("ok %d plate slots beside an end are closed with track fills, idle and casting, on five screens and two plate scales at Full (Subtle draws no ends); no plate draws more than six pieces and no fill covers a rail, an end or plate content at Subtle or Full", closed))
