-- test-core-parity-third.lua: game text font and size, combat numbers, corner-aligned links, the fading toolbar, rail sections and release notes keep defaults and v0.2.8 profiles.
local O = dofile("Tools/regression/options_env.lua")
local env, K, ns = O.New({ saved = { version = 42, profiles = { Default = {
	Appearance = { font = "InterSemiBold", uiScaleAuto = false, uiScale = 0.8 },
} }, layouts = { Default = { ["Parity.Bar"] = { attachTo = "Parity.Base", side = "below", offset = 4 } } } }, before = function(e, k)
	k.Modules.Register(O.W.CoreEnv.Module("Chat", { defaults = { sample = 1 } }))
	k.Modules.Enable("Chat")
	for key, size in pairs({ ["Parity.Base"] = { 200, 40, 0 }, ["Parity.Bar"] = { 80, 20, -100 } }) do
		local frame = e.CreateFrame("Frame", nil, k.Scale.Root())
		frame:SetSize(size[1], size[2])
		k.Layout.Register(frame, key, { anchor = "CENTER", x = 0, y = size[3] }, { module = "Chat", label = key, resizable = true })
	end
end })
local Layout, Mode, Appearance = K.Layout, K.Layout.Mode, K.Appearance
local function row(page, label)
	return assert(O.Find(ns.Pages.Find(ns.Pages.List(), page).Items(), function(item) return item.label == label end), label)
end
local function near(a, b) return math.abs(a - b) < 0.51 end
local function font(name, file, height, flags)
	local got = { env[name]:GetFont() }
	return got[1] == file and math.abs(got[2] - height) < 1e-6 and got[3] == flags
end

for _, spec in ipairs({ { "GameFontNormal", "Fonts\\FRIZQT__.TTF", 12, "" }, { "NumberFontNormal", "Fonts\\ARIALN.TTF", 14, "OUTLINE" },
	{ "KstyleUIProbe", "Fonts\\K.TTF", 10, "" }, { "OtherAddonFont", "Interface\\AddOns\\Other\\Other.ttf", 9, "" } }) do
	env.CreateFont(spec[1]):SetFont(spec[2], spec[3], spec[4])
end
env.GameFontChild = { GetFont = function(self)
	if self.file then return self.file, self.size, self.flags end
	return env.GameFontNormal:GetFont()
end, SetFont = function(self, file, size, flags) self.file, self.size, self.flags = file, size, flags end }
local secretWrites, walks = 0, 0
env.SecretFont = { GetFont = function() return env.Secret("Fonts\\S.TTF"), 12, "" end, SetFont = function() secretWrites = secretWrites + 1 end }
env.GetFonts = function()
	walks = walks + 1
	return { "GameFontNormal", "GameFontChild", "NumberFontNormal", "KstyleUIProbe", "OtherAddonFont", "SecretFont", "MissingFont" }
end
env.STANDARD_TEXT_FONT, env.UNIT_NAME_FONT, env.DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT__.TTF"
local function blizzardDefault()
	for _, setting in ipairs(Appearance.Schema()) do
		if setting.key == "font" then
			for _, option in ipairs(setting.options()) do
				if option.label == "Blizzard Default" then return option.value end
			end
		end
	end
end

assert(K.Appearance.Get("font") == "InterSemiBold" and K.Appearance.Get("uiScale") == 0.8, "v0.2.8 appearance is unchanged")
assert(not row("General", "Use your font for game text").get() and row("General", "Game text size").get() == 1
	and not row("General", "Use your number font for combat text").get() and not row("Elements", "Fade the toolbar until pointed at").get()
	and row("General", "List page sections in the rail").get(), "new options keep today's look by default")
Appearance.Apply()
assert(walks == 0 and font("GameFontNormal", "Fonts\\FRIZQT__.TTF", 12, "") and env.STANDARD_TEXT_FONT == "Fonts\\FRIZQT__.TTF"
	and env.DAMAGE_TEXT_FONT == "Fonts\\FRIZQT__.TTF", "default reloads never touch the game's fonts")
local bl, bb, bw = Layout.Rect("Parity.Base")
local l, b, w, h = Layout.Rect("Parity.Bar")
assert(near(l, bl + (bw - w) / 2) and near(b + h, bb - 4), "a v0.2.8 below link stays centred below its target")

local body, names, number = K.Tokens.Font("body"), K.Tokens.Font("names"), K.Tokens.Font("number")
row("General", "Use your font for game text").set(true)
assert(K.Store.Account().gameFont == true and row("General", "Use your font for game text").get(), "game font writes")
assert(font("GameFontNormal", body, 12, "") and font("NumberFontNormal", body, 14, "OUTLINE"), "game fonts take your font and keep their size and outline")
assert(font("GameFontChild", body, 12, "") and env.GameFontChild.file == nil, "a font that inherits a game font follows it without its own write")
assert(font("KstyleUIProbe", "Fonts\\K.TTF", 10, "") and font("OtherAddonFont", "Interface\\AddOns\\Other\\Other.ttf", 9, ""),
	"KstyleUI's fonts and other addons' own font files keep their faces")
assert(secretWrites == 0, "a font whose values are secret is never written")
assert(env.STANDARD_TEXT_FONT == body and env.UNIT_NAME_FONT == names, "world names follow after relogging")
assert(blizzardDefault() == "Fonts\\FRIZQT__.TTF", "the Blizzard Default font choice stays listed while game text is on")
row("General", "Game text size").set(1.2)
assert(font("GameFontNormal", body, 14.4, "") and row("General", "Game text size").defer, "game text size scales game fonts on release")
env.GameFontNormal:SetFont(body, 18, "")
K.Options.Write("Appearance", "motion", "reduced")
assert(font("GameFontNormal", body, 21.6, ""), "the game's own text size change is kept and scaled")
K.Options.Write("Appearance", "font", "")
assert(font("GameFontNormal", K.Tokens.Font("body"), 21.6, "") and K.Tokens.Font("body") ~= body, "game text follows a font change")
K.Options.Write("Appearance", "font", "InterSemiBold")
row("General", "Use your font for game text").set(false)
row("General", "Game text size").set(1)
assert(font("GameFontNormal", "Fonts\\FRIZQT__.TTF", 18, "") and font("NumberFontNormal", "Fonts\\ARIALN.TTF", 14, "OUTLINE")
	and font("GameFontChild", "Fonts\\FRIZQT__.TTF", 18, "") and env.GameFontChild.file == nil, "turning both off restores the game's fonts exactly")
assert(env.STANDARD_TEXT_FONT == "Fonts\\FRIZQT__.TTF" and env.UNIT_NAME_FONT == "Fonts\\FRIZQT__.TTF", "turning game text off restores the game's globals")
env.GameFontNormal:SetFont("Fonts\\FRIZQT__.TTF", 20, "")
walks = 0
K.Options.Write("Appearance", "motion", "full")
assert(walks == 0 and font("GameFontNormal", "Fonts\\FRIZQT__.TTF", 20, ""), "after game text is off, later settings leave the game's fonts alone")
row("General", "Use your number font for combat text").set(true)
assert(env.DAMAGE_TEXT_FONT == number, "combat numbers use the number font")
row("General", "Use your number font for combat text").set(false)
assert(env.DAMAGE_TEXT_FONT == "Fonts\\FRIZQT__.TTF", "turning combat numbers off restores the game's font")
env.GetFonts = nil
row("General", "Game text size").set(1.3)
assert(#env._errors == 0, "a client without GetFonts keeps working")
ns.Pages.Find(ns.Pages.List(), "General").reset()
assert(not row("General", "Use your font for game text").get() and row("General", "Game text size").get() == 1
	and K.Store.Account().gameTextScale == nil, "General reset clears game text options")

assert(#Layout.SideOptions() == 12, "four sides, each centred or lined up at either edge")
assert(not Layout.Set("Parity.Bar", "side", "aboveTop") and not Layout.Set("Parity.Bar", "side", "middle") and not Layout.Set("Parity.Bar", "side", 5),
	"impossible sides are refused")
for _, case in ipairs({
	{ "aboveLeft", function() return near(l, bl) and near(b, bb + 40) end },
	{ "belowRight", function() return near(l + w, bl + bw) and near(b + h, bb) end },
	{ "rightTop", function() return near(l, bl + bw) and near(b + h, bb + 40) end },
	{ "leftBottom", function() return near(l + w, bl) and near(b, bb) end },
}) do
	assert(Layout.Update("Parity.Bar", { side = case[1], offset = 0 }))
	bl, bb, bw = Layout.Rect("Parity.Base")
	l, b, w, h = Layout.Rect("Parity.Bar")
	assert(case[2](), case[1] .. " lines up the matching edges")
end
local move = Layout.Movement("Parity.Bar", l, b - 10, w, h)
assert(move.offset and near(move.offset, 0) and not move.anchor, "dragging a corner link changes only its gap")
assert(Layout.Update("Parity.Bar", { side = "right", offset = 4 }))
l, b, w, h = Layout.Rect("Parity.Bar")
local steps = 0
debug.sethook(function()
	if debug.getinfo(2, "S").source:match("^@Core/") then steps = steps + 1 end
end, "", 1)
for _ = 1, 100 do Layout.Preview("Parity.Bar", l + 1, b, w, h) end
debug.sethook()
local budget = rawget(_G, "jit") and 1441 or 1379
assert(steps <= budget * 100, "a centred link's drag preview takes " .. steps / 100 .. " addon instructions, budget " .. budget
	.. ": the base path plus the 8-instruction SIDES lookup for corner sides; never parse a side per preview")
Layout.Restore("Parity.Bar")
assert(Layout.Update("Parity.Bar", { side = "leftBottom", offset = 0 }))
assert(Layout.Enter())
Mode.Select("Parity.Bar")
assert(Mode.Plate("Parity.Bar").info:GetText():lower():find("left, bottom edges lined up", 1, true), "the selected plate names the corner side")

local toolbar = Mode.Toolbar()
assert(toolbar:GetAlpha() == 1 and not toolbar:IsMouseEnabled() and toolbar.done:IsVisible(), "the toolbar stays solid by default")
Layout.Exit(true)
row("Elements", "Fade the toolbar until pointed at").set(true)
assert(K.Store.Account().layoutToolbarHover == true, "toolbar fade writes")
assert(Layout.Enter())
assert(toolbar:GetAlpha() == 0.25 and toolbar:IsMouseEnabled(), "the toolbar rests faded")
toolbar._mouseOver = true
toolbar.undo:GetScript("OnEnter")(toolbar.undo)
assert(toolbar:GetAlpha() == 1, "pointing at the toolbar shows it")
toolbar._mouseOver = false
toolbar.undo:GetScript("OnLeave")(toolbar.undo)
assert(toolbar:GetAlpha() == 0.25, "leaving fades it again")
local overlay = Mode.Overlay()
env._modifiers.shift = true
overlay:GetScript("OnKeyDown")(overlay, "LSHIFT")
assert(toolbar:GetAlpha() == 0 and not toolbar:IsMouseEnabled() and not toolbar.titleBar:IsShown() and not toolbar.done:IsVisible(),
	"holding Shift hides the toolbar and nothing on it takes a click")
env._modifiers.shift = nil
overlay:GetScript("OnKeyUp")(overlay, "LSHIFT")
assert(toolbar:GetAlpha() == 0.25 and toolbar:IsMouseEnabled() and toolbar.titleBar:IsShown() and toolbar.done:IsVisible(), "releasing Shift brings it back")
Layout.Exit(true)
row("Elements", "Fade the toolbar until pointed at").set(false)
assert(Layout.Enter() and toolbar:GetAlpha() == 1 and not toolbar:IsMouseEnabled(), "turning the fade off restores the solid toolbar")
Layout.Exit(true)
row("Elements", "Fade the toolbar until pointed at").set(true)
ns.Pages.Find(ns.Pages.List(), "Elements").reset()
assert(K.Store.Account().layoutToolbarHover == nil, "Elements reset clears the toolbar fade")

assert(K.Options.Open("General"))
env.RunTimers()
local function sections()
	for _, entry in ipairs(ns.Window.Parts().rail.items) do if entry.section then return true end end
end
assert(sections() and row("General", "List page sections in the rail").get(), "the rail lists sections by default")
row("General", "List page sections in the rail").set(false)
env.RunTimers()
assert(not sections() and K.Store.Account().optionsRailSections == false, "turning sections off lists pages only")
row("General", "List page sections in the rail").set(true)
env.RunTimers()
assert(sections(), "sections come back")
K.Options.Open("About")
local host = K.Widgets.DialogHost()
local selected = 0
host.editBox.HighlightText = function() selected = selected + 1 end
row("About", "What's new").buttons[1].onClick()
env.RunTimers()
env.RunTimers()
assert(host.editBox:GetText() == "https://github.com/korallis/KstyleUI/releases" and selected == 1, "what's new selects the release notes link, ready to copy")
O.W.Click(host.visibleButtons[1])

local _, again = O.New({ saved = K.Options.Copy(K.Store.Data()), load = false })
assert(again.Store.Decode(assert(again.Store.Export())), "A profile exported after these options decodes before Options loads")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("core parity third ok: game text, combat numbers, corner links, toolbar fade, rail sections, release notes, v0.2.8")
