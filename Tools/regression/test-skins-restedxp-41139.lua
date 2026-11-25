-- test-skins-restedxp-41139.lua: the RestedXP skin applies to RestedXP 4.11.39 (the owner's installed release, which renamed v2:IsGuideWindowEnabled to IsEnabled, UpdateVisuals to UpdateSubTheme and RenderFrame to UpdateTheme, and rebuilt the item and target boxes as RXPV2MiniFrame widgets holding their frames): the entry check passes, the theme draws with RestedXP's live reload on or off, the guide window and arrow follow RestedXP's redraws, and both boxes wear the card's glass and dock under the guide's card. The 4.11.35 shape keeps its own tests.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")

local HOOKED = { SetAlpha = true, SetVertexColor = true, SetColorTexture = true, SetChecked = true, SetFont = true, SetFontObject = true, SetText = true, Show = true, Hide = true, SetShown = true, UpdateSubTheme = true, SetMinMaxValues = true, SetStep = true, SetScale = true, StopMovingOrSizing = true, SetupArrow = true, SetTexture = true, SetRotation = true, SetTexCoord = true }

for _, live in ipairs({ true, false }) do
	local what = live and "live reload on" or "live reload off"
	local rxp
	local env, K, ns = S.New({
		saved = { version = 12, profiles = { Default = { Layout = { preset = "DPS" } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(e)
			e._textWidth = Measure.TextWidth
			Quests.Install(e, Quests.List(3))
			rxp = Fake.Install(e, { release = "4.11.39", liveReload = live, activeTheme = "DarkMode" })
			rxp.currentGuide = { name = "6-10 Durotar" }
		end,
		before = function(e)
			Quests.Tracker(e, S.Blizzard(e))
		end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	rxp.SetStep()
	rxp.targeting:UpdateTargetFrame(1, 0)
	rxp.UpdateItemFrame(nil, 1)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()

	assert(ns.RestedXP.Addon() == rxp, what .. ": the skin's entry check takes 4.11.39's v2:IsEnabled, got " .. tostring((S.Logged(env, "restedXP:"))))
	assert(ns.RestedXP.Theme.Active(rxp), what .. ": the KstyleUI theme draws")
	assert(ns.RestedXP.Rail.Placed(), what .. ": the guide card holds RestedXP's guide")

	for _, name in ipairs({ "RXPFrame.UpdateVisuals", "arrowFrame.UpdateVisuals", "activeItemFrame", "activeTargetFrame" }) do
		assert(not S.Logged(env, name), what .. ": the skin hooks 4.11.39's own name for " .. name .. ", got " .. tostring((S.Logged(env, name))))
	end
	local f, arrow = rxp.RXPFrame, rxp.arrowFrame
	local card = ns.RestedXP.Chrome.Card(f)
	f:UpdateSubTheme()
	arrow:UpdateSubTheme()
	env.RunTimers()
	assert(card and ns.RestedXP.Chrome.Card(f) == card, what .. ": the guide window keeps its card through RestedXP's UpdateSubTheme")
	local layers = 0
	for _, region in ipairs({ arrow:GetRegions() }) do
		if region._masks and #region._masks == 1 and region:IsShown() and region._masks[1]:GetTexture() == arrow.texture:GetTexture() then
			layers = layers + 1
		end
	end
	assert(layers == 2, what .. ": the arrow wears the skin's silhouette and edge, masked by RestedXP's own art, got " .. layers)

	local root = K.Scale.Root()
	local guide = assert(Geometry.ScaledRect(K.Skin.Parts(f).backdrop, env.UIParent, root))
	local gap, px = K.Tokens.Size("gapSmall"), K.Scale.Pixel(1) + 0.01
	for _, which in ipairs({ "items", "targets" }) do
		local box, widget = Fake.Box(rxp, which)
		widget:UpdateSubTheme()
		env.RunTimers()
		S.W.Settle(env)
		local glass = K.Skin.Parts(box) and K.Skin.Parts(box).backdrop
		assert(glass and box:IsShown(), what .. ": the " .. which .. " box, now RestedXP's widget's frame, wears the card's glass")
		assert(ns.RestedXP.Chrome.Caption(widget.title.text), what .. ": and its title on the widget takes the caps caption")
		for _, art in ipairs({ box.rxpBackground, box.rxpBorder, widget.title.rxpBackground }) do
			for _, texture in ipairs(art.textures) do
				assert(texture:GetAlpha() == 0, what .. ": RestedXP's own v2 backdrop stays hushed under the glass after its UpdateSubTheme")
			end
		end
		local r = assert(Geometry.ScaledRect(glass, env.UIParent, root))
		assert(math.abs(guide.bottom - r.top - gap) <= 2 * px, string.format("%s: the %s box docks a small gap under the guide's card, got %.2f", what, which, guide.bottom - r.top))
		local edge = which == "targets" and r.left - guide.left or r.right - guide.right
		assert(math.abs(edge) <= 0.01, string.format("%s: the %s chip's glass meets the guide's %s edge, got %.3f", what, which, which == "targets" and "left" or "right", edge))
		assert(box.savePosition == false, what .. ": and stays out of RestedXP's saved places while docked")
	end

	-- RestedXP's scale settings call SetScale on the boxes directly (SettingsPanel.lua 1859, 3240).
	rxp.targeting:SetScale(1.25)
	rxp.activeItemWindow:SetScale(1.25)
	env.RunTimers()
	S.W.Settle(env)
	guide = assert(Geometry.ScaledRect(K.Skin.Parts(f).backdrop, env.UIParent, root))
	for _, which in ipairs({ "items", "targets" }) do
		local r = assert(Geometry.ScaledRect(K.Skin.Parts((Fake.Box(rxp, which))).backdrop, env.UIParent, root))
		assert(math.abs(guide.bottom - r.top - gap) <= 2 * px, string.format("%s: the %s box docks under the guide again after RestedXP's scale setting, got %.2f", what, which, guide.bottom - r.top))
	end

	assert(rxp.guideReloads == 0, what .. ": the skin's start-up draw repaints without reloading RestedXP's guide (UpdateTheme's skipGuideReload)")
	assert(rxp.v2:GetTheme().name == "KstyleUI", what .. ": 4.11.39's v2 lookup follows the run-time theme, so its v2 windows take the KstyleUI theme (Themes.lua 448)")

	-- A box title that is not a frame, and a button whose IsShown is secret, are left alone.
	local box, widget = Fake.Box(rxp, "targets")
	local title, button = widget.title, widget.enemyTargetButtons[1]
	widget.title = {}
	local ok, err = pcall(ns.RestedXP.Rail.Band)
	widget.title = title
	assert(ok, what .. ": a box title that is not a frame leaves the rail working, got " .. tostring(err))
	local function Upvalue(fn, key)
		for i = 1, 60 do
			local name, value = debug.getupvalue(fn, i)
			if name == key then
				return value
			end
		end
	end
	local Icons = Upvalue(Upvalue(ns.RestedXP.Rail.Band, "Plan"), "Icons")
	button.IsShown = function() return false end
	local hidden = Icons(box)
	button.IsShown = function() return env.Secret(false) end
	local secret = Icons(box)
	button.IsShown = nil
	assert(secret == hidden, string.format("%s: a button whose IsShown is secret counts as hidden in the box's width, got %s against %s", what, tostring(secret), tostring(hidden)))

	rxp.fake.check(HOOKED)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
end

-- With the skin off RestedXP's own geometry stands: 4.11.39 hangs the first item from its frame's top left (6, -15).
do
	local rxp
	local env, K = S.New({ setup = function(e) rxp = Fake.Install(e, { release = "4.11.39" }) end })
	K.Options.Write("Skins", "restedXP.enabled", false)
	env.RunTimers()
	rxp.UpdateItemFrame(nil, 1)
	local point, _, _, x, y = rxp.activeItemWindow.buttonList[1]:GetPoint(1)
	assert(point == "TOPLEFT" and x == 6 and y == -15, "with the skin off, 4.11.39's first item hangs from its frame's top left (6, -15), got " .. tostring(point))
end

-- The restedxp and gallery_restedxp scenes build in 4.11.39's shape, without the report and splits it rebuilt.
rawset(_G, "RENDER_RXP_RELEASE", "4.11.39")
local R = dofile("Tools/render/scenes/_restedxp.lua").Build()
assert(R.windows.targets and R.windows.report == nil and R.windows.splits == nil, "the RestedXP gallery builds on 4.11.39")
local _, itemParts = Fake.Box(R.rxp, "items")
local _, targetParts = Fake.Box(R.rxp, "targets")
assert(itemParts.buttonList[1]:GetWidth() == targetParts.enemyTargetButtons[1]:GetWidth(), "the gallery's item buttons keep RestedXP's 25 units, as its target buttons, got " .. tostring(itemParts.buttonList[1]:GetWidth()))
-- RestedXP's 40-unit option icons do not touch: each 34-unit row sits in a 38-unit wrapper (GuideConfigurator.lua 956) and
-- AceGUI's Flow layout puts 3 units between wrappers, a 41-unit pitch (review of #806, finding 4).
local ui, last = R.rxp.ui.v2.configurator.ui, nil
for _, option in ipairs(Fake.ConfiguratorOptions(ui)) do
	if option.frame:IsShown() then
		local image = assert(dofile("Tools/regression/geometry.lua").Rect(option.image, ui.scrollContainer.frame))
		assert(not last or image.top < last.bottom, "the gallery's option icons must not overlap (Tools/render/scenes/_restedxp.lua OPTION_GAP), got " .. image.top .. " under " .. (last and last.bottom or 0))
		last = image
	end
end

print("skins restedxp 4.11.39 ok")
