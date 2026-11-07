-- test-cooldowns-settings.lua: the Cooldowns settings page registers every setting with a valid row, cleans bad saved values, and builds a live preview that follows the settings.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

-- The module registers with its schema and a preview; every setting has a row.
local env, K, ns = C.New()
local schema = K.Options.Get("Cooldowns")
assert(type(schema) == "table" and #schema > 0, "the Cooldowns settings page is registered")
assert(K.Options.Preview("Cooldowns") == ns.Preview.Build, "the settings page carries the preview builder")
assert(K.Modules.List()[#K.Modules.List()] == "Cooldowns", "the module registers itself")
assert(ns.definition.reskin == true, "the module changes Blizzard's viewers, so turning it off asks for a reload")

local keys = {}
for _, row in ipairs(schema) do
	if row.key then
		keys[row.key] = row
	end
end
local function Covered(prefix, defaults)
	for key, value in pairs(defaults) do
		local full = prefix and (prefix .. "." .. key) or key
		if key ~= "enabled" then
			if type(value) == "table" and value.r == nil then
				Covered(full, value)
			else
				assert(keys[full], "the setting " .. full .. " has no row on the settings page")
			end
		end
	end
end
Covered(nil, ns.Settings.defaults)

-- The spec's minimum customisations are on the page for each icon group.
for _, group in ipairs({ "essential", "utility" }) do
	for _, key in ipairs({ "size", "spacing", "columns", "rows", "growth", "wrap", "timer", "timerSize", "countSize", "readyGlow" }) do
		assert(keys[group .. "." .. key], group .. " needs a " .. key .. " setting")
	end
end
assert(keys["buffs.size"] and keys["buffs.columns"] and keys["buffs.growth"] and keys["buffs.inactive"], "tracked buff icons are an icon group too")
assert(keys["buffs.readyGlow"] == nil, "buff icons have no cooldown-only settings")
for _, key in ipairs({ "width", "height", "spacing", "count", "growth", "texture", "colorSource", "color", "orientation", "reverse", "icon", "name", "timer", "nameSize", "timerSize" }) do
	assert(keys["bars." .. key], "bars need a " .. key .. " setting")
end
assert(keys["bars.texture"].type == "texture", "the bar texture is a texture row")
assert(keys["bars.color"].showWhen({ bars = { colorSource = "custom" } }) and not keys["bars.color"].showWhen({ bars = { colorSource = "class" } }), "the bar colour shows only for a custom source")
local sources = {}
for _, option in ipairs(keys["bars.colorSource"].options) do
	sources[option.value] = true
end
assert(sources.class and sources.reaction and sources.custom, "bars choose class, reaction or custom colour")
local paths = {}
for _, option in ipairs(keys.path.options) do
	paths[option.value] = true
end
assert(paths.auto and paths.mirror and paths.reskin, "the display path is automatic, the mirror or the reskin")
for _, key in ipairs({ "timerFont", "timerOutline", "countFont", "countOutline", "nameFont", "nameOutline", "accent", "accentColor", "path" }) do
	assert(keys[key], "the page needs a " .. key .. " setting")
end
assert(keys.accentColor.showWhen({ accent = "custom" }) and not keys.accentColor.showWhen({ accent = "class" }), "the custom colour shows only for a custom accent")

-- Defaults match the spec's HUD sizes.
local defaults = ns.Settings.defaults
assert(defaults.essential.size == K.Tokens.Size("cooldownEssential") and defaults.essential.size == 40, "essential icons are 40 units")
assert(defaults.utility.size == K.Tokens.Size("cooldownUtility") and defaults.utility.size == 30, "utility icons are 30 units")
assert(defaults.essential.spacing == 3 and defaults.essential.columns == 6, "six icons per row with 3-unit gaps")
assert(defaults.bars.width == 180 and defaults.bars.height == 18 and defaults.bars.count == 3, "three bars of 180 by 18 units")
assert(defaults.path == "auto", "the path is automatic by default")

-- The font dropdown lists the kit font first, then the media fonts as paths.
local fonts = ns.Settings.FontOptions()
assert(fonts[1].value == "kit", "the kit font comes first")
assert(#fonts > 1 and fonts[2].value:find("\\", 1, true), "media fonts follow, stored as paths")

-- Saved values outside what the page allows are cleaned, not trusted.
do
	local saved = {
		version = 1,
		profiles = {
			Default = {
				Cooldowns = {
					essential = { size = 500, spacing = -4, columns = 2.6, growth = "diagonal", timer = "yes" },
					timerFont = "C:\\evil|.ttf",
					bars = { texture = "bad|path", count = 99, colorSource = "plaid" },
					path = "sideways",
					accent = "rainbow",
					accentColor = { r = 2, g = 0, b = 0 },
				},
			},
		},
	}
	local _, _, ns2 = C.New({ saved = saved })
	local current = ns2.Settings.Read()
	local e = current.essential
	assert(e.size == 64, "a size past the slider clamps to 64, got " .. tostring(e.size))
	assert(e.spacing == 0, "a negative gap clamps to 0")
	assert(e.columns == 3, "columns round to a whole step")
	assert(e.growth == "center", "an unknown growth falls back to the default")
	assert(e.timer == true, "a timer switch that is not a boolean falls back to on")
	assert(current.timerFont == "kit", "a bad font path falls back to the kit font")
	assert(current.accent == "class", "an unknown accent source falls back to class")
	assert(current.bars.texture == defaults.bars.texture, "a texture path with a pipe falls back to the default")
	assert(current.bars.count == 12 and current.bars.colorSource == "class", "bar values clamp and fall back")
	assert(current.path == "auto", "an unknown path falls back to automatic")
	local r = current.accentR
	assert(r == defaults.accentColor.r, "a colour channel past 1 gives the default colour")
end

-- The preview builds sample rows and follows a settings change through Refresh.
do
	local parent = env.CreateFrame("Frame", nil, env.UIParent)
	parent:SetSize(280, 300)
	local elements = #K.Layout.Elements()
	local frame = ns.Preview.Build(parent)
	assert(#K.Layout.Elements() == elements, "the preview's sample rows are not Layout elements")
	assert(frame and frame.Refresh, "the preview returns a frame with Refresh")
	local essential = frame.rows.essential
	assert(essential.count == 6 and frame.rows.utility.count == 4, "the preview shows six essential and four utility samples")
	assert(frame.rows.buffs.count == 3 and frame.rows.bars.count == 2, "the preview shows sample buffs and bars")
	assert(frame.rows.bars.bars[1].name:GetText() == "Rapid Fire", "a sample bar carries a name")
	assert(essential.icons[1].icon:GetTexture() == 132176, "sample icons are real ability icons")
	assert(#W.Calls(essential.icons[1].cooldown, "SetCooldown") == 1, "a sample icon shows a cooldown sweep")
	assert(essential.icons[4].proc == true, "a sample proc glows")
	K.Options.Write("Cooldowns", "essential.size", 32)
	frame:Refresh()
	assert(essential.icons[1].opts.size == 32, "the preview follows the icon size")
	assert(essential.holder:GetWidth() <= 280, "the preview row fits the pane")
end

print("cooldowns settings ok")
