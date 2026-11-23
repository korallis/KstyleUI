-- test-setup-first-run.lua: a new profile starts on Medallions and the Forged look; setup shows one big picture of each layout (and of each arrangement on wide screens), loaded only while it is open; one-click Looks set only existing settings, Forged is the way back, and Off restores the small pictures and hides the Looks.
local W = dofile("Tools/regression/widget_env.lua")
local O = dofile("Tools/regression/options_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Gallery = dofile("Tools/render/scenes/_gallery.lua")
local Scene = Common.Scene
local Guard = dofile("Tools/render/guard.lua")

local function Boot(screen, locale)
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], size = "auto" })
	rawset(_G, "RENDER_LOCALE", locale or "enUS")
	rawset(_G, "RENDER_ORNAMENTS", "Full")
	local env, K = W.New(Common.ScreenOpts({ saved = Gallery.Saved({}), boot = false, setup = function(e)
		Gallery.Setup(e)
		e._textWidth = function(text, path, points) return Scene.TextWidth(Scene.PlainText(text), points, path) end
	end }))
	W.CoreEnv.Boot(env)
	return env, K
end

local function Settle(env)
	env.RunTimers(); W.Settle(env); env.RunTimers()
end

local function Fits(env, what)
	local findings = Guard.Check(Scene.Build(env))
	assert(#findings == 0, what .. ": " .. tostring(findings[1] and findings[1].subject))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

local function Picture(name)
	return "Interface\\AddOns\\KstyleUI\\Media\\Textures\\Setup\\" .. name .. ".tga"
end

-- A new profile: Medallions, the Forged look, and setup's default path is still one click.
do
	local env, K = Boot({ 1920, 1080 })
	assert(K.HudStyle.Saved() == "medallions" and K.Setup.NewChoice().hudStyle == "medallions", "a new profile starts on Medallions")
	assert(K.Setup.Looks.Current() == "Forged" and K.Setup.NewChoice().look == "Forged", "a new profile wears the Forged look")
	assert(K.Setup.NewChoice().arrangement == "centred", "setup starts on the saved arrangement")
	local writes = {}
	K.Callbacks.Register("SettingChanged", "test", function(_, module, key) writes[module .. "." .. key] = true end)
	K.Store.Account().setupSeen = nil
	assert(K.Setup.Open(true))
	K.Setup.window:Close()
	Settle(env)
	assert(K.Store.Account().setupSeen and K.Options.Read("Layout", "preset") == "DPS", "closing the first run still applies the default setup")
	for _, path in ipairs({ "Widgets.ornaments", "Widgets.cardMaterial", "Widgets.panelOpacity", "Medallions.motion", "Appearance.outline", "Layout.arrangement" }) do
		assert(not writes[path], "the default setup leaves the look alone: " .. path)
	end
end

-- Big pictures: one picture of the layout you point at, in your HUD style, loaded only while setup is open.
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K = Boot(screen)
	local wide = screen[1] / screen[2] > 2.4
	assert(K.Setup.Open())
	local panel = K.Setup.window
	assert(panel.preview.picture:GetTexture() == nil, "no big picture loads before the layout step")
	for _, style in ipairs({ "medallions", "frames" }) do
		local Style = style == "medallions" and "Medallions" or "Frames"
		K.Setup.Choice().hudStyle = style
		K.Setup.Go(2)
		Settle(env)
		assert(panel.lookTabs:IsShown() and panel.lookTabs:GetValue() == "Forged", "the HUD style step offers the Looks, Forged first")
		Fits(env, string.format("HUD style step with Looks, %s at %dx%d", Style, screen[1], screen[2]))
		K.Setup.Go(3)
		Settle(env)
		local preview = panel.preview
		assert(preview:IsShown() and preview.picture:IsShown() and preview.picture:GetTexture() == Picture(Style .. "DPS"), "the layout step shows the big " .. Style .. " DPS picture")
		assert(preview:GetWidth() >= 440 and math.abs(preview:GetWidth() / preview:GetHeight() - 16 / 9) < 0.02, "the picture is large and 16:9")
		for _, card in pairs(panel.cards) do
			assert(not card.picture:IsShown() and card.picture:GetTexture() == nil, "the small card pictures neither show nor load")
		end
		for _, rect in ipairs(preview.rects) do assert(not rect:IsShown(), "the footprint diagram hides under the picture") end
		W.Enter(panel.cards.Healer)
		assert(preview.picture:GetTexture() == Picture(Style .. "Healer"), "pointing at Healer shows its picture")
		W.Leave(panel.cards.Healer)
		assert(preview.picture:GetTexture() == Picture(Style .. "DPS"), "leaving shows the chosen layout again")
		for _, card in pairs(panel.arrangeCards) do assert(card:IsShown() == wide, "arrangement cards show only where the arrangement matters") end
		if wide then
			W.Enter(panel.arrangeCards.spread)
			assert(preview.picture:GetTexture() == Picture(Style .. "Spread"), "pointing at Spread shows it")
			assert(math.abs(preview.picture:GetWidth() / preview.picture:GetHeight() - 32 / 9) < 0.05, "an arrangement picture keeps its 32:9 shape")
			W.Leave(panel.arrangeCards.spread)
		end
		Fits(env, string.format("layout step, %s at %dx%d", Style, screen[1], screen[2]))
		K.Setup.Go(5)
		Settle(env)
		assert(panel.summaryPreview.picture:GetTexture() == Picture(Style .. "DPS"), "the summary shows the chosen layout's picture")
		assert(panel.summary:GetText():find("Look: Forged.", 1, true), "the summary names the Look")
		Fits(env, string.format("summary, %s at %dx%d", Style, screen[1], screen[2]))
	end
	if wide then
		W.Click(panel.arrangeCards.spread)
		assert(K.Setup.Choice().arrangement == "spread")
		K.Setup.Go(5)
		assert(panel.summary:GetText():find("Arrangement: Spread.", 1, true), "the summary names the arrangement")
		W.Click(panel.apply)
		assert(K.Options.Read("Layout", "arrangement") == "spread", "Apply writes the arrangement picked on the layout step")
	end
	panel:Close()
	Settle(env)
	assert(panel.preview.picture:GetTexture() == nil and panel.summaryPreview.picture:GetTexture() == nil, "closing setup releases the big pictures")
	collectgarbage("collect")
end

-- Every locale fits the Looks row, the arrangement cards and the summary.
for _, locale in ipairs({ "deDE", "frFR", "esES", "zhCN" }) do
	for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
		local env, K = Boot(screen, locale)
		assert(K.Setup.Open())
		for _, step in ipairs({ 2, 3, 5 }) do
			K.Setup.Go(step)
			Settle(env)
			Fits(env, string.format("%s step %d at %dx%d", locale, step, screen[1], screen[2]))
		end
		K.Setup.window:Close()
		collectgarbage("collect")
	end
end

-- Looks set existing settings only; the current Look is read back from them; Forged is the way back.
do
	local env, K = Boot({ 1920, 1080 })
	local Looks = K.Setup.Looks
	local before = K.Options.Copy(K.Store.Profile())
	assert(Looks.Apply("Clean") and Looks.Current() == "Clean", "Clean applies in one call")
	assert(K.Options.Read("Widgets", "ornaments") == "Off" and K.Options.Read("Medallions", "ambient") == false and K.Options.Read("Appearance", "motion") == "reduced", "Clean sets plain trim, a still hub and calm motion")
	assert(Looks.Apply("Readable") and Looks.Current() == "Readable", "Readable applies in one call")
	assert(K.Store.Module("Readability").preset == "Readable" and K.Options.Read("Widgets", "cardMaterial") == "Slate", "Readable grows text on solid panels")
	assert(K.Options.Read("Medallions", "ambient") == true, "each Look is complete: Readable puts back what Clean changed")
	assert(Looks.Apply("Forged") and Looks.Current() == "Forged", "Forged is the way back")
	for _, module in ipairs({ "Widgets", "Medallions", "Appearance", "Readability", "UnitFrames" }) do
		if before[module] then assert(K.Options.Equal(K.Store.Profile()[module], before[module]), "Forged restores every " .. module .. " value a Look changed") end
	end
	K.Options.Write("Widgets", "ornaments", "Subtle")
	assert(Looks.Current() == nil and K.Setup.NewChoice().look == "Custom", "a setting of your own matches no Look")
	assert(not Looks.Apply("Custom") and K.Options.Read("Widgets", "ornaments") == "Subtle", "keeping your own look changes nothing")
	for key in pairs(K.Store.Profile()) do assert(key ~= "Looks", "a Look keeps no saved state of its own") end
	-- The setup row: picking a Look applies it with the setup; Off hides it.
	assert(K.Setup.Open())
	K.Setup.Go(2)
	Settle(env)
	local panel = K.Setup.window
	assert(panel.lookTabs:GetValue() == "Custom", "setup shows Your own for a custom look")
	panel.lookTabs:Select("Clean")
	assert(K.Setup.Choice().look == "Clean" and K.Options.Read("Widgets", "ornaments") == "Subtle", "picking a Look waits for Apply")
	panel.lookTabs:Select("Custom")
	assert(K.Setup.Choice().look == "Custom", "Your own stays available after trying a Look")
	panel.lookTabs:Select("Clean")
	assert(K.Setup.Apply(K.Setup.Choice()) and Looks.Current() == "Clean", "Apply wears the picked Look")
	K.Options.Write("Setup", "looks", false)
	K.Setup.Go(2)
	Settle(env)
	assert(not panel.lookTabs:IsShown() and not panel.lookNote:IsShown(), "Off hides the Looks in setup")
	K.Options.Write("Setup", "bigPictures", false)
	K.Setup.Go(3)
	Settle(env)
	assert(not panel.preview:IsShown(), "Off restores the small pictures")
	for name, card in pairs(panel.cards) do
		assert(card.picture:IsShown() and card.picture:GetTexture():find("LayoutMedallions" .. name .. ".tga", 1, true), "Off shows the small " .. name .. " picture")
	end
	panel:Close()
	Settle(env)
end

-- The settings window: a Look row under the HUD style, in one click, and hidden when Off.
do
	local env, K, ns = O.New()
	local function Row()
		for _, row in ipairs(ns.Window.Parts().content.rows) do
			if row:IsShown() and row.item and row.item.label == "Look" then return row end
		end
	end
	K.Options.Open("General")
	Settle(env)
	local row = Row()
	assert(row and row.item.kind == "segmented" and row.controls.segmented:GetValue() == "Forged", "General offers the Looks, on Forged")
	row.controls.segmented:Select("Clean")
	Settle(env)
	assert(K.Setup.Looks.Current() == "Clean" and Row().controls.segmented:GetValue() == "Clean", "one click wears Clean")
	K.Options.Write("Setup", "looks", false)
	Settle(env)
	assert(not Row(), "Off hides the Look row")
end

-- Readable never shrinks the text the player sees, in either HUD style, and owns every size it sets.
for _, frames in ipairs({ false, true }) do
	local _, K, uf = dofile("Tools/regression/unitframes_env.lua").New({ frames = frames })
	local function Size(element) return select(2, uf.Settings.Font("player", element)) end
	local name, power = Size("name"), Size("power")
	assert(K.Setup.Looks.Apply("Readable"))
	assert(Size("name") >= name and Size("power") > power, string.format("Readable grows text on %s: name %s -> %s, power %s -> %s", K.HudStyle.Current(), name, Size("name"), power, Size("power")))
	local path, readable = "player.fonts.name.size", K.Options.Read("UnitFrames", "player.fonts.name.size")
	K.Options.Write("UnitFrames", path, readable + 1)
	assert(K.Setup.Looks.Current() == nil, "a text size of your own matches no Look")
	assert(K.Setup.Looks.Apply("Readable") and K.Options.Read("UnitFrames", path) == readable and K.Setup.Looks.Current() == "Readable", "picking Readable again sets every size it owns")
end

-- Setup writes only what you pick: changes made while it is open survive Close, and a Look picked before the Looks are turned off is dropped.
do
	local env, K = O.New()
	assert(K.Setup.Open(true))
	K.Options.Write("Widgets", "panelOpacity", 0.31)
	K.Options.Write("Layout", "arrangement", "spread")
	K.Setup.window:Close()
	Settle(env)
	assert(K.Options.Read("Widgets", "panelOpacity") == 0.31 and K.Scale.Arrangement() == "spread", "closing setup keeps what you changed while it was open")
	assert(K.Setup.Open())
	local panel = K.Setup.window
	K.Setup.Go(2)
	Settle(env)
	panel.lookTabs:Select("Clean")
	K.Options.Write("Setup", "looks", false)
	Settle(env)
	assert(not panel.lookTabs:IsShown(), "turning the Looks off hides the row at once")
	K.Setup.Go(5)
	Settle(env)
	assert(K.Setup.Apply(K.Setup.Choice()) and K.Options.Read("Widgets", "panelOpacity") == 0.31, "Apply ignores a Look picked before the Looks were turned off")
	panel:Close()
end

-- The settings window offers Your own only as the status of custom settings.
do
	local env, K, ns = O.New()
	local function Row()
		for _, row in ipairs(ns.Window.Parts().content.rows) do
			if row:IsShown() and row.item and row.item.label == "Look" then return row end
		end
	end
	K.Options.Open("General")
	Settle(env)
	assert(#Row().item.options == 3, "on Forged the Look row offers the three Looks only")
	K.Options.Write("Widgets", "ornaments", "Subtle")
	Settle(env)
	assert(#Row().item.options == 4 and Row().controls.segmented:GetValue() == "Custom", "custom settings show Your own")
end

-- Big pictures load only on the step that shows them and are released when turned off; a closed setup builds no Look tabs.
do
	local env, K = O.New()
	assert(K.Setup.Open())
	local panel = K.Setup.window
	K.Setup.Go(2)
	Settle(env)
	assert(panel.preview.picture:GetTexture() == nil, "the layout step's picture waits for the layout step")
	K.Setup.Go(3)
	Settle(env)
	assert(panel.preview.picture:GetTexture(), "the layout step loads its picture")
	K.Options.Write("Setup", "bigPictures", false)
	Settle(env)
	assert(panel.preview.picture:GetTexture() == nil, "turning Big pictures off releases the picture")
	panel:Close()
	Settle(env)
	local rebuilt, set = 0, panel.lookTabs.SetTabs
	panel.lookTabs.SetTabs = function(...) rebuilt = rebuilt + 1; return set(...) end
	K.Callbacks.Fire("ThemeChanged")
	assert(rebuilt == 0, "a closed setup rebuilds no Look tabs")
end

-- The arrangement pictures show the DPS layout, and say so whichever layout is picked.
do
	local env, K = Boot({ 5120, 1440 })
	assert(K.Setup.Open())
	K.Setup.Choice().layout = "Healer"
	K.Setup.Go(3)
	Settle(env)
	W.Enter(K.Setup.window.arrangeCards.spread)
	local shown = K.Setup.window.previewName:GetText()
	assert(shown:find("DPS", 1, true), "an arrangement picture names the DPS layout it shows: " .. shown)
	K.Setup.window:Close()
end

-- Each setup picture ships once, as a full-size DXT BLP2; the render harness decodes its own copy.
for _, name in ipairs(dofile("Tools/regression/fs.lua").list("Media/Textures/Setup")) do
	local file = assert(io.open("Media/Textures/Setup/" .. name, "rb"))
	local head = file:read(20)
	file:close()
	assert(name:match("%.blp$") and head:sub(1, 4) == "BLP2" and head:byte(9) == 2, name .. ": ship each picture once, as a DXT-compressed BLP2")
	assert(head:byte(13) + 256 * head:byte(14) == 1024, name .. " keeps its 1024-pixel width, crisp at 3840x2160")
end

print("setup first run ok")
