-- test-ornament-nameplates.lua: plate frames keep one pixel clear of a plate's icons and of its text outside the bar's own snapped rim, never cover a drawn fill pixel; every enemy plate shows its level, and Off draws nothing.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local EPS = 0.001

local PLATES = {
	{ token = "nameplate1", x = 300, y = 220, unit = { name = "Riverglade Crocolisk", health = 864, maxHealth = 1540, level = 38, reaction = 2, canAttack = true, threat = 3 } },
	{ token = "nameplate2", x = 300, y = 400, unit = { name = "Riverglade Snapper", health = 1420, maxHealth = 1540, level = 37, reaction = 2, canAttack = true } },
	{ token = "nameplate3", x = 760, y = 220, unit = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, threat = 2, raid = 8 } },
	{ token = "nameplate4", x = 760, y = 400, unit = { name = "Leduc", health = 3100, maxHealth = 3400, level = 60, reaction = 5, canAttack = false, isPlayer = true, class = "PALADIN" } },
	{ token = "nameplate5", x = 1220, y = 220, unit = { name = "Onyxia", health = 900000, maxHealth = 1000000, level = -1, classification = "worldboss", reaction = 2, canAttack = true } },
	{ token = "nameplate6", x = 1220, y = 400, unit = { name = "Ashwing Rare", health = 4000, maxHealth = 5000, level = 41, classification = "rareelite", reaction = 2, canAttack = true, raid = 1 } },
}

local function grown(rect, by)
	return { rect[1] - by, rect[2] - by, rect[3] + 2 * by, rect[4] + 2 * by }
end

local function overlap(a, b)
	return a[1] < b[1] + b[3] - EPS and b[1] < a[1] + a[3] - EPS and a[2] < b[2] + b[4] - EPS and b[2] < a[2] + a[4] - EPS
end

local function subtract(a, b)
	local ax2, ay2, bx2, by2 = a[1] + a[3], a[2] + a[4], b[1] + b[3], b[2] + b[4]
	if not overlap(a, b) then return { a } end
	local out = {}
	if a[2] < b[2] then out[#out + 1] = { a[1], a[2], a[3], b[2] - a[2] } end
	if ay2 > by2 then out[#out + 1] = { a[1], by2, a[3], ay2 - by2 } end
	local top, bottom = math.max(a[2], b[2]), math.min(ay2, by2)
	if a[1] < b[1] then out[#out + 1] = { a[1], top, b[1] - a[1], bottom - top } end
	if ax2 > bx2 then out[#out + 1] = { bx2, top, ax2 - bx2, bottom - top } end
	return out
end

local RIM_SHARED = { name = true, healthText = true, castName = true, castTime = true }
local FILLS = { health = true, cast = true }

local function content(plate)
	local list = { name = plate.name, healthText = plate.healthText, levelText = plate.levelText, level = plate.level,
		marker = plate.marker, raid = plate.raid, castName = plate.castName, castTime = plate.castTime,
		castIcon = plate.castIcon, castShield = plate.castShield }
	list.health = plate.health and plate.health._barTexture
	list.cast = plate.castBar and plate.castBar._barTexture
	for key, group in pairs(plate.auras and plate.auras._groups or {}) do
		for i, button in ipairs(group.frames or {}) do list["aura." .. key .. i] = button end
	end
	return list
end

local function run(width, height, scale, level, extras)
	local env, K, ns = N.New({ width = width, height = height, uiScale = extras and 768 / 1080 or nil })
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
	if extras then
		K.Options.Write("Nameplates", "level.show", true)
		K.Options.Write("Nameplates", "cast.showIcon", true)
	end
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Snap", text = "Snap", texture = 132200, notInterruptible = false })
	N.Cast(env, "nameplate3", { name = "Terrifying Screech", text = "Terrifying Screech", texture = 136124, notInterruptible = true })
	N.Cast(env, "nameplate5", { name = "Deep Breath", text = "Deep Breath", texture = 136124, notInterruptible = true })
	for _ = 1, 20 do N.Tick(env, 0.05) end
	N.Debuffs(env, "nameplate1", 3)
	env.RunTimers()
	for _ = 1, 10 do N.Tick(env, 0.05) end
	Scene.Build(env)
	K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
	local label = string.format("%s %dx%d scale %.2f%s", level, width, height, scale, extras and " at the shipped Interface size with level discs and spell icons" or "")
	local pixel = 1080 / height
	local scene = Scene.Build(env)
	local solver = Scene.RectSolver(env)
	local rects = {}
	for _, item in ipairs(scene.items) do rects[item.object] = item.rect end
	for _, spec in ipairs(PLATES) do
		local plate = ns.Plates.Get(spec.token)
		local pieces = 0
		for _, handle in ipairs({ plate.ornament, plate.castOrnament }) do
			for i = 1, handle.used do
				local texture = handle.textures[i]
				if texture:IsVisible() then
					local rect = assert(rects[texture], label .. ": " .. spec.token .. " ornament piece not drawn")
					pieces = pieces + 1
					local tx, ty, tw, th = Scene.RectIn(solver, handle.target)
					local rim = (handle.target.rimOutset or 0) * tw / handle.target:GetWidth()
					local band = grown({ tx, ty, tw, th }, rim)
					local function snap(v) return math.floor(v / pixel + 0.5) * pixel end
					local x1, y1 = snap(band[1]), snap(band[2])
					band = { x1, y1, snap(band[1] + band[3]) - x1, snap(band[2] + band[4]) - y1 }
					for name, object in pairs(content(plate)) do
						if object.IsVisible and object:IsVisible() then
							local x, y, w, h = Scene.RectIn(solver, object)
							local ink = object.GetStringWidth and object:GetStringWidth()
							if x and type(ink) == "number" and ink > 0 and (tonumber(object:GetWidth()) or 0) > 0 and ink < object:GetWidth() then
								local factor, justify = w / object:GetWidth(), object:GetJustifyH()
								local inkW = ink * factor
								x = justify == "LEFT" and x or justify == "RIGHT" and x + w - inkW or x + (w - inkW) / 2
								w = inkW
							end
							if x and w > 0 and h > 0 and FILLS[name] then
								local fx, fy = snap(x), snap(y)
								local fill = { fx, fy, snap(x + w) - fx, snap(y + h) - fy }
								assert(not overlap(rect, fill),
									string.format("%s: %s ornament %s [%.2f,%.2f,%.2f,%.2f] covers a drawn pixel of %s [%.2f,%.2f,%.2f,%.2f]",
										label, spec.token, tostring(texture:GetTexture()), rect[1], rect[2], rect[3], rect[4], name, fill[1], fill[2], fill[3], fill[4]))
							elseif x and w > 0 and h > 0 then
								for _, part in ipairs(RIM_SHARED[name] and subtract(rect, band) or { rect }) do
									assert(not overlap(grown(part, pixel - EPS), { x, y, w, h }),
										string.format("%s: %s ornament %s [%.2f,%.2f,%.2f,%.2f] within one pixel of %s [%.2f,%.2f,%.2f,%.2f]",
											label, spec.token, tostring(texture:GetTexture()), rect[1], rect[2], rect[3], rect[4], name, x, y, w, h))
								end
							end
						end
					end
				end
			end
		end
		if level == "Off" then
			assert(pieces == 0, label .. ": Off draws ornament art on " .. spec.token)
		elseif spec.unit.canAttack then
			local ends = 0
			for i = 1, plate.ornament.used do
				if (plate.ornament.textures[i]:GetTexture() or ""):match("End%a+%d+%.png$") then ends = ends + 1 end
			end
			assert(ends ~= 1 and plate.ornament.used >= 1, label .. ": " .. spec.token .. " health frame reads as changed, with both ends or none (" .. plate.ornament.used .. " pieces, " .. ends .. " ends)")
		end
	end
	assert(#env._errors == 0, label .. ": " .. tostring(env._errors[1]))
end

for _, screen in ipairs({ { 1280, 720 }, { 1920, 1080 }, { 3456, 2234 }, { 3840, 2160 } }) do
	for _, scale in ipairs({ 1, 0.58 }) do
		for _, level in ipairs({ "Off", "Subtle", "Full" }) do
			run(screen[1], screen[2], scale, level)
			if level ~= "Off" then run(screen[1], screen[2], scale, level, true) end
		end
	end
end
print("ok plate frames keep one pixel clear of plate content on four screens and two plate scales, with and without level discs and spell icons")
