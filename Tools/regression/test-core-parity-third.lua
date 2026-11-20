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

local fonts = {}
for name, spec in pairs({ GameFontNormal = { "Fonts\\FRIZQT__.TTF", 12, "" }, NumberFontNormal = { "Fonts\\ARIALN.TTF", 14, "OUTLINE" }, KstyleUIProbe = { "Fonts\\K.TTF", 10, "" } }) do
	fonts[name] = env.CreateFont(name)
	fonts[name]:SetFont(spec[1], spec[2], spec[3])
end
env.SecretFont = { GetFont = function() return env.Secret("Fonts\\S.TTF"), 12, "" end, SetFont = function() error("secret fonts are never rewritten") end }
env.GetFonts = function() return { "GameFontNormal", "NumberFontNormal", "KstyleUIProbe", "SecretFont", "MissingFont" } end

assert(K.Appearance.Get("font") == "InterSemiBold" and K.Appearance.Get("uiScale") == 0.8, "v0.2.8 appearance is unchanged")
local on, scale, combat = Appearance.GameText()
assert(not on and scale == 1 and not combat, "game text options start off")
Appearance.Apply()
assert(select(1, fonts.GameFontNormal:GetFont()) == "Fonts\\FRIZQT__.TTF" and env.STANDARD_TEXT_FONT == nil and env.DAMAGE_TEXT_FONT == nil,
	"default reloads never touch the game's fonts")
local function rect(key) return Layout.Rect(key) end
local bl, bb, bw = rect("Parity.Base")
local l, b, w, h = rect("Parity.Bar")
assert(near(l, bl + (bw - w) / 2) and near(b + h, bb - 4), "a v0.2.8 below link stays centred below its target")

local body, names, number = K.Tokens.Font("body"), K.Tokens.Font("names"), K.Tokens.Font("number")
row("General", "Use your font for game text").set(true)
assert(K.Store.Account().gameFont == true and row("General", "Use your font for game text").get(), "game font writes")
local path, height, flags = fonts.GameFontNormal:GetFont()
assert(path == body and height == 12 and flags == "", "native fonts take your font and keep their size and outline")
path, height, flags = fonts.NumberFontNormal:GetFont()
assert(path == body and height == 14 and flags == "OUTLINE", "every native font follows")
assert(select(1, fonts.KstyleUIProbe:GetFont()) == "Fonts\\K.TTF", "KstyleUI's own fonts keep their role")
assert(env.STANDARD_TEXT_FONT == body and env.UNIT_NAME_FONT == names, "world names follow after relogging")
row("General", "Game text size").set(1.2)
path, height = fonts.GameFontNormal:GetFont()
assert(path == body and math.abs(height - 14.4) < 1e-6, "game text size scales native fonts")
assert(row("General", "Game text size").defer, "game text size applies on release")
K.Options.Write("Appearance", "font", "")
assert(select(1, fonts.GameFontNormal:GetFont()) == K.Tokens.Font("body") and K.Tokens.Font("body") ~= body, "game text follows a font change")
K.Options.Write("Appearance", "font", "InterSemiBold")
row("General", "Use your font for game text").set(false)
row("General", "Game text size").set(1)
path, height, flags = fonts.GameFontNormal:GetFont()
assert(path == "Fonts\\FRIZQT__.TTF" and height == 12 and flags == "", "turning both off restores the game's fonts")
row("General", "Use your number font for combat text").set(true)
assert(env.DAMAGE_TEXT_FONT == number, "combat numbers use the number font")
env.GetFonts = nil
assert(pcall(Appearance.ApplyGameText), "a client without GetFonts keeps working")
row("General", "Game text size").set(1.3)
ns.Pages.Find(ns.Pages.List(), "General").reset()
on, scale, combat = Appearance.GameText()
assert(not on and scale == 1 and not combat and K.Store.Account().gameTextScale == nil, "General reset clears game text options")

assert(#Layout.SideOptions() == 12, "four sides, each centred or lined up at either edge")
assert(not Layout.Set("Parity.Bar", "side", "aboveTop") and not Layout.Set("Parity.Bar", "side", "middle"), "impossible sides are refused")
for side, check in pairs({
	aboveLeft = function() return near(l, bl) and near(b, bb + 40) end,
	belowRight = function() return near(l + w, bl + bw) and near(b + h, bb) end,
	rightTop = function() return near(l, bl + bw) and near(b + h, bb + 40) end,
	leftBottom = function() return near(l + w, bl) and near(b, bb) end,
}) do
	assert(Layout.Update("Parity.Bar", { side = side, offset = 0 }))
	bl, bb, bw = rect("Parity.Base")
	l, b, w, h = rect("Parity.Bar")
	assert(check(), side .. " lines up the matching edges")
end
local move = Layout.Movement("Parity.Bar", l, b - 10, w, h)
assert(move.offset and near(move.offset, 0) and not move.anchor, "dragging a corner link changes only its gap")
assert(Layout.Enter())
Mode.Select("Parity.Bar")
assert(Mode.Plate("Parity.Bar").info:GetText():lower():find("left, bottom edges lined up", 1, true), "the selected plate names the corner side")

local toolbar = Mode.Toolbar()
assert(toolbar:GetAlpha() == 1 and not toolbar:IsMouseEnabled(), "the toolbar stays solid by default")
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
env.IsShiftKeyDown = function() return true end
overlay:GetScript("OnKeyDown")(overlay, "LSHIFT")
assert(toolbar:GetAlpha() == 0, "holding Shift hides it")
env.IsShiftKeyDown = nil
overlay:GetScript("OnKeyUp")(overlay, "LSHIFT")
assert(toolbar:GetAlpha() == 0.25, "releasing Shift brings it back")
Layout.Exit(true)
row("Elements", "Fade the toolbar until pointed at").set(false)
assert(Layout.Enter() and toolbar:GetAlpha() == 1, "turning the fade off restores the solid toolbar")
Layout.Exit(true)

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
row("About", "What's new").buttons[1].onClick()
local host = K.Widgets.DialogHost()
assert(host.editBox:GetText() == "https://github.com/korallis/KstyleUI/releases", "what's new offers the release notes link to copy")
O.W.Click(host.visibleButtons[1])

local _, again = O.New({ saved = K.Options.Copy(K.Store.Data()), load = false })
assert(again.Store.Decode(assert(again.Store.Export())), "A profile exported after these options decodes before Options loads")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("core parity third ok: game text, combat numbers, corner links, toolbar fade, rail sections, release notes, v0.2.8")
