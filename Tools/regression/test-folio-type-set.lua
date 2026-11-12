-- test-folio-type-set.lua: Folio is the inherited default, Lumen stays intact, and migrations never replace saved font overrides.
local Core = dofile("Tools/regression/core_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local folio = {
	display = "FolioDisplay-Regular.ttf", heading = "FolioDisplay-Regular.ttf",
	title = "FolioCaps-SemiBold.ttf", caps = "FolioCaps-SemiBold.ttf",
	names = "CinzelNames-SemiBold.ttf", unit = "CinzelUnit-SemiBold.ttf",
	body = "PTSerif-Regular.ttf", prose = "PTSerif-Regular.ttf", caption = "PTSerif-Regular.ttf",
	world = "PTSerif-Regular.ttf", timer = "PTSerif-Regular.ttf",
	number = "PTSerif-Bold.ttf", time = "PTSerif-Bold.ttf",
}
local function file(path)
	return path:match("([^\\/]+)$")
end
local env, K = W.New()
assert(K.Appearance.Get("typeSet") == "Folio" and K.Appearance.Get("font") == "")
for role, name in pairs(folio) do
	assert(file(K.Tokens.Font(role)) == name, role .. " inherits " .. name)
end
assert(K.Tokens.TextStyle("caption") == 0 and K.Locale.TrackMode(K.Tokens.Font("caption")) == nil)
assert(K.Locale.TrackMode(K.Tokens.Font("caps")) == "face")
assert(K.Locale.TrackMode("Interface\\AddOns\\OtherMedia\\Font.ttf") == nil, "unknown faces never receive synthetic tracking")
assert(K.Locale.TrackMode(K.Tokens.FontPath("AlegreyaSansRegular")) == "space", "the known legacy face keeps its tracking")
K.Options.Write("Appearance", "typeSet", "Lumen")
assert(file(K.Tokens.Font("caps")) == "CinzelCaps-Medium.ttf")
assert(file(K.Tokens.Font("number")) == "AlegreyaSansTabular-ExtraBold.ttf")
assert(K.Tokens.TextStyle("caption") == 0.6)
local chosen = "Interface\\AddOns\\OtherMedia\\Font.ttf"
K.Options.Write("Appearance", "font", chosen)
K.Options.Write("Appearance", "typeSet", "Folio")
assert(K.Tokens.Font("body") == chosen, "an existing whole-interface override wins over a set change")
assert(file(K.Tokens.Font("number")) == "SourceSans3-Semibold.ttf", "legacy global overrides preserve their numeric behavior")
K.Options.Write("Appearance", "font", "")
assert(file(K.Tokens.Font("body")) == "PTSerif-Regular.ttf")

local picker = K.Widgets.FontPicker(K.Scale.Root(), { value = "" })
assert(picker, "a picker can be built with the inherited value")
for _, option in ipairs(picker:GetOptions()) do
	assert(option.value ~= "", "ordinary font pickers do not promise inheritance")
end
picker:SetOptions(K.Widgets.InheritedFontOptions)
assert(picker:GetOptions()[1].value == "" and picker.text:GetText() == K.L["Interface font"], "only an opted-in list exposes and labels inheritance")
assert(#picker:GetOptions() == #K.Widgets.MediaOptions("font") + 1, "the inherited list retains every available font")

for _, code in ipairs({ "deDE", "frFR", "esES", "zhCN" }) do
	local _, localized = W.New({ setup = function(e)
		e.GetLocale = function() return code end
	end })
	for role, name in pairs(folio) do
		local path = localized.Tokens.Font(role)
		assert(file(path) == (code == "zhCN" and "ARKai_T.ttf" or name), code .. " " .. role)
	end
	localized.Options.Write("Appearance", "typeSet", "Lumen")
	if code == "zhCN" then
		assert(localized.Tokens.Font("body") == "Fonts\\ARKai_T.ttf", "the client fallback is unchanged for Lumen")
	end
end

local saved = {
	version = 17,
	profiles = {
		Default = {},
		Original = { Appearance = { font = "Lumen" }, Chat = { font = chosen }, Auras = { timer = { font = chosen } } },
		Custom = { Appearance = { font = "InterSemiBold" }, GroupFrames = { text = { nameFont = chosen } } },
		ChatSize = { Chat = { fontSize = 16 } },
		ChatSpacing = { Chat = { lineSpacing = 8 } },
		ChatBoth = { Chat = { fontSize = 15, lineSpacing = 7 } },
		ChatInherited = { Chat = {} },
	},
}
local migratedEnv, migrated = Core.New({ saved = saved })
Core.Boot(migratedEnv)
assert(migrated.Store.Data().version == 21)
local profiles = migrated.Store.Data().profiles
assert(profiles.ChatSize.Chat.fontSize == 16 and profiles.ChatSize.Chat.lineSpacing == 4.5, "custom size preserves its old inherited spacing")
assert(profiles.ChatSpacing.Chat.fontSize == 14 and profiles.ChatSpacing.Chat.lineSpacing == 8, "custom spacing preserves its old inherited size")
assert(profiles.ChatBoth.Chat.fontSize == 15 and profiles.ChatBoth.Chat.lineSpacing == 7, "two explicit values are unchanged")
assert(profiles.ChatInherited.Chat.fontSize == nil and profiles.ChatInherited.Chat.lineSpacing == nil, "fully inherited chat receives both new defaults")
assert(migrated.Theme.FontFace() == "Folio", "a profile with no saved choice receives the new set")
migrated.Store.SetProfile("Original")
assert(migrated.Appearance.Get("typeSet") == "Lumen" and migrated.Appearance.Get("font") == "")
assert(migrated.Theme.FontFace() == "Lumen", "a saved choice of the original set is preserved")
assert(migrated.Store.Module("Chat").font == chosen and migrated.Store.Module("Auras").timer.font == chosen)
migrated.Options.Write("Appearance", "typeSet", "Folio")
assert(migrated.Store.Module("Chat").font == chosen, "changing the type set never clears an element override")
migrated.Store.SetProfile("Custom")
assert(migrated.Theme.FontFace() == "InterSemiBold")
assert(migrated.Store.Module("GroupFrames").text.nameFont == chosen)
Core.Logout(migratedEnv)
assert(saved.profiles.Custom.GroupFrames.text.nameFont == chosen, "logout keeps an explicit path")

local glyphs = dofile("Tools/render/glyphs.lua")
local path = K.Tokens.Font("body")
local widths = glyphs["PTSerif-Regular"]
assert(widths[233] and widths[338], "the glyph table includes accented letters and capitals")
assert(math.abs(Scene.TextWidth("éŒ", 10, path) - (widths[233] + widths[338]) * 10) < 1e-8, "UTF-8 uses real advances rather than generic lowercase widths")
assert(#env._errors == 0 and #migratedEnv._errors == 0)
print("folio type set ok")
