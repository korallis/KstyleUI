-- test-text-floor.lua: no KstyleUI text under 11 px at 1080 lines (bible 3.6, KSTY-60 item 2), cast labels and spell names out of Cinzel, which is for unit names (KSTY-60 item 11), and class-coloured names lifted to a readable luminance.
rawset(_G, "RENDER_SCENE_LIB", true)

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local FLOOR = 11
local CAST = { ["LIGHTNING BOLT"] = true, ["SHADOW BOLT"] = true }

local function hud(width, height, style)
	rawset(_G, "RENDER_HUD_STYLE", style)
	local Reference = dofile("Tools/render/scenes/_reference.lua")
	Reference.SCREEN = { width = width, height = height, uiScale = 768 / 1080, size = "auto" }
	local scene = Reference.Build({ layout = "DPS" })
	rawset(_G, "RENDER_HUD_STYLE", nil)
	return scene
end

for _, case in ipairs({ { 1920, 1080, "Frames" }, { 1920, 1080, "Orbs" }, { 5120, 1440, "Frames" } }) do
	local width, height, style = case[1], case[2], case[3]
	local label = width .. "x" .. height .. " " .. style
	local scene = hud(width, height, style)
	local texts, casts = 0, 0
	for _, item in ipairs(scene.items) do
		local file = item.kind == "text" and item.font and tostring(item.font.file) or ""
		if file:find("^Media/") then
			texts = texts + 1
			assert(item.font.size >= FLOOR - 1e-6, string.format("%s: '%s' is %.2f px at 1080 lines, under the %d px floor", label, tostring(item.text), item.font.size, FLOOR))
			local words = tostring(item.text)
			if CAST[words] then
				casts = casts + 1
				assert(not file:find("Cinzel", 1, true), label .. ": the cast label '" .. words .. "' is not in Cinzel, which is for unit names, got " .. file)
			end
		end
	end
	assert(texts > 80, label .. ": the HUD draws its texts, got " .. texts)
	assert(casts >= 1, label .. ": a cast label is drawn")
	collectgarbage("collect")
end

do
	local scene = dofile("Tools/render/scenes/gallery_skins_spellbook.lua")()
	local spells = 0
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and item.font and (item.text == "Mortal Strike" or item.text == "Overpower") then
			spells = spells + 1
			assert(not tostring(item.font.file):find("Cinzel", 1, true), "the spellbook's spell name '" .. item.text .. "' is not in Cinzel, got " .. tostring(item.font.file))
		end
	end
	assert(spells == 2, "the spellbook draws its spell names")
end

do
	local CoreEnv = dofile("Tools/regression/core_env.lua")
	local env, K = CoreEnv.New({ width = 1920, height = 1080 })
	CoreEnv.Boot(env)
	local Theme = K.Theme
	local function luminance(r, g, b)
		return 0.2126 * r + 0.7152 * g + 0.0722 * b
	end
	for _, class in ipairs({ "SHAMAN", "DEATHKNIGHT", "WARLOCK", "PRIEST", "MAGE", "DRUID" }) do
		local r, g, b = Theme.ClassTextColorForWidget(class)
		local cr, cg, cb = Theme.ClassColorForWidget(class)
		assert(luminance(r, g, b) >= 0.5 - 1e-6, class .. ": a class-coloured name is lifted to a readable luminance")
		if luminance(cr, cg, cb) >= 0.5 then
			assert(near(r, cr) and near(g, cg) and near(b, cb), class .. ": a light class colour is unchanged")
		else
			assert(r >= cr and g >= cg and b >= cb, class .. ": a dark class colour only moves towards white")
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("text floor ok")
