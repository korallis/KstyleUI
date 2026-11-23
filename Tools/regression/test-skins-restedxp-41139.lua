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
		assert(box.savePosition == false, what .. ": and stays out of RestedXP's saved places while docked")
	end

	rxp.fake.check(HOOKED)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
end

print("skins restedxp 4.11.39 ok")
