-- test-skins-restedxp-theme.lua: the RestedXP skin registers a KstyleUI theme with RestedXP, makes it the active theme while its switch is on, keeps it in step with the accent and font, and gives the player's own theme back when it turns off.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local W = S.W

local NAME = "KstyleUI"

local function Near(list, r, g, b, a)
	return type(list) == "table" and W.Near(list[1], r) and W.Near(list[2], g) and W.Near(list[3], b) and (a == nil or W.Near(list[4] or 1, a))
end

-- Boot(opts) -> env, K, ns, rxp: KstyleUI with RestedXP loaded, the Skins module on.
local function Boot(opts)
	opts = opts or {}
	local rxp
	local env, K, ns = S.New({
		setup = function(env)
			rxp = Fake.Install(env, opts)
		end,
	})
	K.Modules.Enable("Skins")
	env.RunTimers()
	return env, K, ns, rxp
end

local function Memory(K, rxp)
	local all = K.Store.Account().restedXPTheme
	return type(all) == "table" and all[rxp.settings.GetSettingsDB()] or nil
end

-- The theme: KstyleUI's surfaces, text and accent, in RestedXP's v1 and v2 theme fields --------------------

do
	local env, K, ns, rxp = Boot({ v2 = true, activeTheme = "DarkMode" })
	local v1, v2 = rxp.themes[NAME], rxp.v2.themes[NAME]
	assert(type(v1) == "table", "the v1 theme is registered through RegisterTheme")
	assert(type(v2) == "table", "the v2 theme is in RestedXP's v2 themes")
	assert(v1.name == NAME and v1.author and v1.applicable == true, "the theme names itself and applies in every mode")
	local sr, sg, sb = K.Tokens.Color("surface")
	local opacity = K.Widgets.Setting("panelOpacity")
	assert(Near(v1.background, sr, sg, sb, opacity), "the background is the glass surface at the panel opacity")
	assert(Near(v2.backgroundColors.guideWindow, sr, sg, sb, opacity), "the v2 guide window is the glass surface")
	local ar, ag, ab = ns.Style.Accent()
	assert(Near(v1.mapPins, ar, ag, ab), "map pins take the accent")
	assert(Near(v2.mapPins, ar, ag, ab), "v2 map pins take the accent")
	assert(Near(v2.textColor.title, ar, ag, ab), "v2 titles take the accent")
	assert(Near(v2.borderColors.common, ar, ag, ab), "v2 borders take the accent")
	assert(Near(v1.bottomFrameHighlight, ar, ag, ab), "the v1 highlight takes the accent")
	assert(v1.tooltip == string.format("|cff%02x%02x%02x", math.floor(ar * 255 + 0.5), math.floor(ag * 255 + 0.5), math.floor(ab * 255 + 0.5)), "tooltip text takes the accent")
	local tr, tg, tb = K.Tokens.Color("text")
	assert(Near(v2.textColor.common, tr, tg, tb), "v2 text is KstyleUI's text colour")
	local er, eg, eb = K.Tokens.Color("textEmphasis")
	assert(Near(v1.textColor, er, eg, eb), "v1 guide text is KstyleUI's emphasised text")
	assert(v1.font == (ns.Style.Font("body")), "the theme uses KstyleUI's font")
	assert(v2.font == v1.font)
	assert(v2.version and v2.version > 1, "the v2 theme outranks the v1 one, so RestedXP never converts over it")
	rxp.v2:ConvertThemes()
	assert(rxp.v2.themes[NAME] == v2 and not v2.converted, "RestedXP's conversion leaves the v2 theme alone")
	local base = rxp.v2.themes["RXP Blue V2"]
	assert(v2.guideWindow.logo == base.guideWindow.logo, "RestedXP's own icons stay: the theme reads them from RestedXP at run time")
	assert(v2.navigationArrow == base.navigationArrow)
	assert(v1.texturePath == rxp.themes.DarkMode.texturePath, "v1 art comes from RestedXP's dark set, read at run time")
	assert(v1.edges.edge == v1.texturePath .. "rxp-borders" and v1.edges.guideName == v1.edges.edge, "v1 edges are RestedXP's dark border art, so a window KstyleUI does not restyle keeps a dark edge")
	for piece in pairs(v1.edges) do
		assert(piece == "edge" or piece == "guideName", "v1 edges name only RestedXP's backdrop pieces: " .. tostring(piece))
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Activation: the switch makes the theme RestedXP's active theme and remembers the player's own --------------

do
	local env, K, ns, rxp = Boot({ v2 = true, activeTheme = "DarkMode" })
	assert(ns.Skins.IsApplied("restedXP"), "the skin applies once RestedXP has loaded")
	assert(rxp.settings.profile.activeTheme == NAME, "the KstyleUI theme is active")
	assert(rxp.reloads >= 1, "RestedXP redraws with it")
	assert(rxp.v2:GetTheme() == rxp.v2.themes[NAME], "the v2 window resolves the KstyleUI theme")
	local memory = Memory(K, rxp)
	assert(memory and memory.original == "DarkMode", "the player's own theme is remembered, per RestedXP profile")
	local reloads = rxp.reloads
	K.Options.Write("Skins", "restedXP.enabled", false)
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == "DarkMode", "switching it off gives the player's theme back")
	assert(rxp.reloads > reloads, "and RestedXP redraws")
	K.Options.Write("Skins", "restedXP.enabled", true)
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == NAME, "switching it on again makes it active again")
	rxp.settings.profile.activeTheme = "RXP Green"
	K.Options.Write("Skins", "restedXP.enabled", false)
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == "RXP Green", "a theme the player picked since is kept: only KstyleUI's own is undone")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local rxp
	local env, K = S.New({
		setup = function(env)
			rxp = Fake.Install(env, { activeTheme = "DarkMode" })
		end,
	})
	K.Modules.Enable("Skins")
	assert(rxp.settings.profile.activeTheme == NAME and rxp.reloads == 1, "at login the theme is active and drawn at once, not a frame later")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, _, rxp = Boot({ activeTheme = "RXP Green" })
	assert(rxp.settings.profile.activeTheme == NAME, "the v1 window gets the theme too")
	K.Modules.Disable("Skins")
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == "RXP Green", "turning the Skins module off restores the player's theme")
	K.Modules.Enable("Skins")
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == NAME, "turning it on again activates the theme again")
	K.Store.Module("Skins").restedXP.enabled = false
	K.Store.CopyProfile(K.Store.ProfileName(), "No RestedXP")
	K.Store.SetProfile("No RestedXP")
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == "RXP Green", "a KstyleUI profile with the switch off restores it")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, _, rxp = Boot({ activeTheme = "DarkMode" })
	rxp.SwitchProfile("Shared", { activeTheme = "RXP Green", enableThemeLiveReload = true })
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == NAME, "a RestedXP profile change keeps the theme active")
	assert(Memory(K, rxp).original == "RXP Green", "each RestedXP profile remembers its own theme")
	K.Options.Write("Skins", "restedXP.enabled", false)
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == "RXP Green")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, _, rxp = Boot({ activeTheme = "DarkMode" })
	local first = rxp.settings.profile
	rxp.SwitchProfile("Second", { activeTheme = "RXP Green", enableThemeLiveReload = true })
	env.RunTimers()
	K.Options.Write("Skins", "restedXP.enabled", false)
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == "RXP Green", "switching off restores the profile RestedXP shows")
	rxp.SwitchProfile("Tester - Realm", first)
	env.RunTimers()
	assert(first.activeTheme == "DarkMode", "and a profile the player returns to while it is off gets its own theme back too")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K, _, rxp = Boot({ activeTheme = NAME })
	assert(rxp.settings.profile.activeTheme == NAME)
	assert(rxp.activeTheme == rxp.themes[NAME], "a theme saved from an earlier session, which RestedXP could not find at its start-up, is drawn once registered")
	K.Options.Write("Skins", "restedXP.enabled", false)
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == "RXP Blue", "with no theme remembered, RestedXP's default comes back")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- In step: an accent, font, opacity or profile change rebuilds the theme and redraws RestedXP once -----------

do
	local env, K, ns, rxp = Boot({ v2 = true })
	local v1, v2 = rxp.themes[NAME], rxp.v2.themes[NAME]
	local reloads = rxp.reloads
	K.Theme.SetCustomAccent(0.2, 0.4, 0.9)
	K.Theme.SetAccentSource("custom")
	env.RunTimers()
	assert(rxp.themes[NAME] == v1 and rxp.v2.themes[NAME] == v2, "the same theme tables, rebuilt in place")
	assert(Near(v1.mapPins, 0.2, 0.4, 0.9) and Near(v2.textColor.title, 0.2, 0.4, 0.9), "the new accent reaches the theme")
	assert(rxp.reloads == reloads + 1, "RestedXP redraws once for a burst of changes")
	K.Theme.SetCustomAccent(0.3, 0.5, 0.7)
	K.Theme.SetFontFace("SourceSans3Regular")
	env.RunTimers()
	assert(rxp.reloads == reloads + 2, "two changes before the next frame redraw once")
	K.Options.Write("Skins", "accent.source", "custom")
	K.Options.Write("Skins", "accent.color", { r = 0.9, g = 0.1, b = 0.3 })
	env.RunTimers()
	assert(Near(v2.borderColors.common, 0.9, 0.1, 0.3), "the Skins module's own accent wins, as in every skinned window")
	K.Theme.SetFontFace("InterSemiBold")
	env.RunTimers()
	assert(v1.font == K.Tokens.FontPath("InterSemiBold") and v2.font == v1.font, "a font change reaches the theme")
	K.Options.Write("Widgets", "panelOpacity", 0.7)
	env.RunTimers()
	assert(W.Near(v1.background[4], 0.7), "the panel opacity reaches the glass background")
	assert(ns.Skins.IsApplied("restedXP"))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- RestedXP's live theme reload off: the theme is still written, and RestedXP draws it --------------------------

do
	local env, K, _, rxp = Boot({ liveReload = false, activeTheme = "DarkMode" })
	assert(rxp.settings.profile.activeTheme == NAME, "the theme is still made active")
	assert(rxp.reloads == 0 and rxp.renders == 0, "but RestedXP draws it after /reload, as with any theme change while its live reload is off")
	assert(S.Logged(env, "live theme reload is off"), "the devlog says why")
	K.Options.Write("Skins", "restedXP.enabled", false)
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == "DarkMode", "switching off still gives the player's theme back")
	assert(rxp.renders == 0)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, _, _, rxp = Boot({ liveReload = false, activeTheme = NAME })
	assert(rxp.reloads == 0, "RestedXP's live reload stays off")
	assert(rxp.renders == 1 and rxp.lastRender == "themeReload" and rxp.arrows == 1, "after /reload, the start-up draw RestedXP could not do with the theme is done once")
	assert(rxp.activeTheme == rxp.themes[NAME], "so the windows show it from login")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Combat: the theme waits for combat to end -----------------------------------------------------------------

do
	local env, K, _, rxp = Boot({ activeTheme = "DarkMode" })
	env.SetCombat(true)
	local reloads = rxp.reloads
	K.Options.Write("Skins", "restedXP.enabled", false)
	env.RunTimers()
	assert(rxp.reloads == reloads and rxp.settings.profile.activeTheme == NAME, "nothing changes in combat")
	env.SetCombat(false)
	env.RunTimers()
	assert(rxp.settings.profile.activeTheme == "DarkMode", "the restore runs when combat ends")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- RestedXP missing: nothing happens and nothing errors ---------------------------------------------------------

do
	local env, K, ns = S.New({})
	K.Modules.Enable("Skins")
	env.RunTimers()
	assert(not ns.Skins.IsApplied("restedXP"), "no RestedXP, no skin")
	K.Options.Write("Skins", "restedXP.enabled", false)
	K.Options.Write("Skins", "restedXP.enabled", true)
	K.Modules.Disable("Skins")
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(env.RXPGuides_Themes == nil, "no stray RestedXP globals")
end

do
	local env, K, ns = S.New({ loaded = { RXPGuides = true }, setup = Fake.Bare })
	K.Modules.Enable("Skins")
	env.RunTimers()
	assert(S.Logged(env, "RestedXP is not loaded"), "a RestedXP that AceAddon does not know is logged once")
	K.Options.Write("Skins", "restedXP.enabled", false)
	K.Options.Write("Skins", "restedXP.enabled", true)
	K.Modules.Disable("Skins")
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(ns.Skins.IsApplied("restedXP"))
end

do
	local env, K = S.New({ loaded = { RXPGuides = true } })
	K.Modules.Enable("Skins")
	env.RunTimers()
	assert(#env._errors == 0, "no LibStub at all: " .. tostring(env._errors[1]))
end

print("skins restedxp theme ok")
