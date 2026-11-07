-- test-theme.lua: the accent follows the player's class or a custom colour, and changes fire ThemeChanged and ClassChanged.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local core = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if not path:match("^KstyleUI_") then
		core[#core + 1] = path
	end
end

-- Blizzard's class colours for the classes the tests use.
local CLASS = {
	WARRIOR = { 0.78, 0.61, 0.43 },
	MAGE = { 0.25, 0.78, 0.92 },
	PRIEST = { 1, 1, 1 },
}

local function colorObject(c)
	return {
		r = c[1], g = c[2], b = c[3],
		GetRGB = function(self)
			return self.r, self.g, self.b
		end,
	}
end

-- opts: class (the player's class file name, or false for none), classColorApi (default true),
-- raidColors (default false), secretClass.
local function NewTheme(opts)
	opts = opts or {}
	local env = Stubs.NewEnv()
	env._class = opts.class == nil and "WARRIOR" or opts.class
	function env.UnitClass(unit)
		assert(unit == "player", "Theme reads only the player's class")
		if not env._class then
			return nil
		end
		local file = opts.secretClass and env.Secret(env._class) or env._class
		return "Localized", file, 1
	end
	if opts.classColorApi ~= false then
		env.C_ClassColor = {
			GetClassColor = function(name)
				-- As in the game: a secret class name gives a colour whose channels are secret.
				if env.issecretvalue(name) then
					local c = CLASS[env.Reveal(name)]
					return c and colorObject({ env.Secret(c[1]), env.Secret(c[2]), env.Secret(c[3]) }) or nil
				end
				local c = CLASS[name]
				return c and colorObject(c) or nil
			end,
		}
	end
	if opts.raidColors then
		env.RAID_CLASS_COLORS = {}
		for name, c in pairs(CLASS) do
			env.RAID_CLASS_COLORS[name] = colorObject(c)
		end
	end
	Load(core, env)
	local ns = env.KstyleUI
	-- Record every callback. If the dispatcher exists, it still runs.
	local fired = {}
	local dispatch = ns.Callbacks.Fire
	ns.Callbacks.Fire = function(event, ...)
		fired[#fired + 1] = { event = event, n = select("#", ...), ... }
		if dispatch then
			dispatch(event, ...)
		end
	end
	return env, ns, fired
end

local function same(a, b)
	return math.abs(a - b) < 1e-9
end

local function assertColor(label, want, r, g, b)
	assert(same(r, want[1]) and same(g, want[2]) and same(b, want[3]), string.format("%s: got %.3f %.3f %.3f, want %.3f %.3f %.3f", label, r, g, b, want[1], want[2], want[3]))
end

local function events(fired)
	local names = {}
	for _, f in ipairs(fired) do
		names[#names + 1] = f.event
	end
	return table.concat(names, " ")
end

local function default(ns)
	local r, g, b = ns.Tokens.Color("accentDefault")
	return { r, g, b }
end

-- Login resolves the class colour and announces the class, then the theme.
do
	local env, ns, fired = NewTheme({ class = "WARRIOR" })
	env.FireEvent("PLAYER_LOGIN")
	assertColor("warrior accent", CLASS.WARRIOR, ns.Theme.Accent())
	assertColor("Tokens accent", CLASS.WARRIOR, ns.Tokens.Color("accent"))
	assert(select(4, ns.Tokens.Color("accent")) == 1, "the accent is opaque")
	assert(events(fired) == "ClassChanged ThemeChanged", "login fires ClassChanged then ThemeChanged, got: " .. events(fired))
	assert(fired[1][1] == "WARRIOR" and fired[1][2] == nil, "ClassChanged passes the new class and the old one")
	assert(ns.Theme.Class() == "WARRIOR", "Theme.Class names the player's class")

	-- Review Focus 1: the player logs in on a different class. Every open window restyles in its
	-- ThemeChanged handler, so the new accent must be in place before the callback fires.
	local seen
	local dispatch = ns.Callbacks.Fire
	ns.Callbacks.Fire = function(event, ...)
		if event == "ThemeChanged" then
			seen = { ns.Tokens.Color("accent") }
		end
		dispatch(event, ...)
	end
	fired[#fired] = nil
	fired[#fired] = nil
	env._class = "MAGE"
	env.FireEvent("PLAYER_LOGIN")
	assertColor("mage accent after a class change", CLASS.MAGE, ns.Theme.Accent())
	assert(seen, "a class change fires ThemeChanged")
	assertColor("accent seen inside ThemeChanged", CLASS.MAGE, seen[1], seen[2], seen[3])
	assert(events(fired) == "ClassChanged ThemeChanged", "a class change fires ClassChanged then ThemeChanged, got: " .. events(fired))
	assert(fired[1][1] == "MAGE" and fired[1][2] == "WARRIOR", "ClassChanged passes MAGE and WARRIOR")

	-- The same class again changes nothing and fires nothing.
	for i = #fired, 1, -1 do
		fired[i] = nil
	end
	env.FireEvent("PLAYER_LOGIN")
	assert(#fired == 0, "a login on the same class fires nothing, got: " .. events(fired))
end

-- The accent resolves on first use, before PLAYER_LOGIN, without firing anything.
do
	local _, ns, fired = NewTheme({ class = "PRIEST" })
	assertColor("priest accent before login", CLASS.PRIEST, ns.Theme.Accent())
	assert(#fired == 0, "reading the accent fires nothing")
end

-- A custom colour replaces the class colour, and survives a class change.
do
	local env, ns, fired = NewTheme({ class = "WARRIOR" })
	env.FireEvent("PLAYER_LOGIN")
	for i = #fired, 1, -1 do
		fired[i] = nil
	end
	assert(ns.Theme.AccentSource() == "class", "the accent follows the class by default")
	assertColor("default custom colour", default(ns), ns.Theme.CustomAccent())
	assert(ns.Theme.SetCustomAccent(0.2, 0.4, 0.6) == true, "a valid custom colour is accepted")
	assert(#fired == 0, "changing the custom colour while it is unused fires nothing")
	assert(ns.Theme.SetAccentSource("custom") == true, "custom is a valid source")
	assertColor("custom accent", { 0.2, 0.4, 0.6 }, ns.Theme.Accent())
	assert(events(fired) == "ThemeChanged", "switching to custom fires ThemeChanged, got: " .. events(fired))
	assert(ns.Theme.SetCustomAccent(0.3, 0.4, 0.6) == true)
	assert(events(fired) == "ThemeChanged ThemeChanged", "a new custom colour fires ThemeChanged")
	assert(ns.Theme.SetAccentSource("custom") == true)
	assert(#fired == 2, "setting the same source again fires nothing")

	for _, bad in ipairs({ { 1.2, 0, 0 }, { -0.1, 0, 0 }, { "1", 0, 0 }, { 0 / 0, 0, 0 }, { env.Secret(0.5), 0, 0 } }) do
		assert(ns.Theme.SetCustomAccent(bad[1], bad[2], bad[3]) == false, "an invalid custom colour is refused")
	end
	assert(ns.Theme.SetAccentSource("rainbow") == false, "an unknown source is refused")
	assertColor("custom accent unchanged", { 0.3, 0.4, 0.6 }, ns.Theme.Accent())

	env._class = "MAGE"
	env.FireEvent("PLAYER_LOGIN")
	assert(events(fired) == "ThemeChanged ThemeChanged ClassChanged", "a class change under a custom accent fires only ClassChanged, got: " .. events(fired))
	assertColor("custom accent after a class change", { 0.3, 0.4, 0.6 }, ns.Theme.Accent())

	assert(ns.Theme.SetAccentSource("class") == true)
	assertColor("back to the class colour", CLASS.MAGE, ns.Theme.Accent())
end

-- Fallbacks: RAID_CLASS_COLORS without C_ClassColor, then the default accent.
do
	local env, ns = NewTheme({ class = "MAGE", classColorApi = false, raidColors = true })
	env.FireEvent("PLAYER_LOGIN")
	assertColor("RAID_CLASS_COLORS fallback", CLASS.MAGE, ns.Theme.Accent())
end
do
	local env, ns = NewTheme({ class = "MAGE", classColorApi = false })
	env.FireEvent("PLAYER_LOGIN")
	assertColor("no class colour source", default(ns), ns.Theme.Accent())
end
do
	local env, ns = NewTheme({ class = false })
	env.FireEvent("PLAYER_LOGIN")
	assertColor("no class", default(ns), ns.Theme.Accent())
	assert(ns.Theme.Class() == nil, "an unknown class is nil")
end
do
	local env, ns = NewTheme({ class = "MAGE", secretClass = true })
	env.FireEvent("PLAYER_LOGIN")
	assertColor("a secret class falls back without touching it", default(ns), ns.Theme.Accent())
end

-- Colours for other units, items and reactions.
do
	local env, ns = NewTheme({ class = "WARRIOR" })
	assertColor("ClassColor", CLASS.MAGE, ns.Theme.ClassColor("MAGE"))
	local tr, tg, tb = ns.Tokens.Color("text")
	assertColor("unknown class", { tr, tg, tb }, ns.Theme.ClassColor("NOTACLASS"))
	assertColor("nil class", { tr, tg, tb }, ns.Theme.ClassColor(nil))
	local r, g, b = ns.Theme.ClassColor(env.Secret("MAGE"))
	assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "a secret class name still gives a colour")

	env.Enum = { ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 } }
	local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [5] = { 1, 0.5, 0 }, [7] = { 0.05, 0.05, 0.3 } }
	env.C_Item = {
		GetItemQualityColor = function(q)
			local c = QUALITY[q]
			if c then
				return c[1], c[2], c[3], "ffffffff"
			end
		end,
	}
	local rr, rg, rb = ns.Tokens.Color("rare")
	assertColor("rare from Tokens", { rr, rg, rb }, ns.Theme.QualityColor(3))
	local er, eg, eb = ns.Tokens.Color("epic")
	assertColor("epic from Tokens", { er, eg, eb }, ns.Theme.QualityColor(4))
	assertColor("uncommon from the game", QUALITY[2], ns.Theme.QualityColor(2))
	local dr, dg, db = ns.Theme.QualityColor(7)
	local lum = 0.2126 * dr + 0.7152 * dg + 0.0722 * db
	assert(lum >= ns.Theme.MIN_LUMINANCE - 1e-9 and db > dr, "a dark quality colour is brightened for the glass, keeping its hue")
	assertColor("unknown quality", { tr, tg, tb }, ns.Theme.QualityColor(99))
	env.C_Item = nil
	env.ITEM_QUALITY_COLORS = { [5] = colorObject(QUALITY[5]) }
	assertColor("ITEM_QUALITY_COLORS fallback", QUALITY[5], ns.Theme.QualityColor(5))

	local function token(name)
		local a, b2, c = ns.Tokens.Color(name)
		return { a, b2, c }
	end
	assertColor("hated", token("hostile"), ns.Theme.ReactionColor(1))
	assertColor("unfriendly", token("hostile"), ns.Theme.ReactionColor(3))
	assertColor("neutral", token("neutral"), ns.Theme.ReactionColor(4))
	assertColor("friendly", token("friendly"), ns.Theme.ReactionColor(5))
	assertColor("exalted", token("friendly"), ns.Theme.ReactionColor(8))
	assertColor("no reaction", token("neutral"), ns.Theme.ReactionColor(nil))
	assertColor("a secret reaction is never compared", token("neutral"), ns.Theme.ReactionColor(env.Secret(2)))
end

-- Class colours for widget setters: a secret class name gives the secret class colour, passed on whole.
do
	local env, ns = NewTheme({ class = "WARRIOR" })
	local r, g, b = ns.Theme.ClassColorForWidget(env.Secret("MAGE"))
	assert(env.issecretvalue(r) and env.issecretvalue(g) and env.issecretvalue(b), "a secret class gives the secret colour for a widget setter")
	assertColor("the secret colour is the class colour", CLASS.MAGE, env.Reveal(r), env.Reveal(g), env.Reveal(b))
	assertColor("a plain class gives the plain class colour", CLASS.MAGE, ns.Theme.ClassColorForWidget("MAGE"))
	local tr, tg, tb = ns.Tokens.Color("text")
	assertColor("an unknown secret class falls back to text", { tr, tg, tb }, ns.Theme.ClassColorForWidget(env.Secret("NOTACLASS")))
	assertColor("ClassColor still gives plain numbers for a secret class", { tr, tg, tb }, ns.Theme.ClassColor(env.Secret("MAGE")))
end
do
	local env, ns = NewTheme({ classColorApi = false })
	local tr, tg, tb = ns.Tokens.Color("text")
	assertColor("no C_ClassColor: a secret class falls back to text", { tr, tg, tb }, ns.Theme.ClassColorForWidget(env.Secret("MAGE")))
end

-- Threat colours come from the reaction tokens, not Blizzard's raw palette.
do
	local env, ns = NewTheme()
	local function token(name)
		local a, b2, c = ns.Tokens.Color(name)
		return { a, b2, c }
	end
	local n, h = token("neutral"), token("hostile")
	assertColor("threat 1, higher threat than the tank, is neutral", n, ns.Theme.ThreatColor(1))
	assertColor("threat 2, insecurely tanking, is between neutral and hostile", { (n[1] + h[1]) / 2, (n[2] + h[2]) / 2, (n[3] + h[3]) / 2 }, ns.Theme.ThreatColor(2))
	assertColor("threat 3, securely tanking, is hostile", h, ns.Theme.ThreatColor(3))
	assert(ns.Theme.ThreatColor(0) == nil, "no threat gives no colour")
	assert(ns.Theme.ThreatColor(nil) == nil, "a missing status gives no colour")
	assert(ns.Theme.ThreatColor(env.Secret(3)) == nil, "a secret status is never compared")
end

-- The UI font face.
do
	local _, ns, fired = NewTheme()
	assert(ns.Theme.FontFace() == "SourceSans3Semibold", "Source Sans 3 Semibold is the default face")
	assert(ns.Theme.SetFontFace("InterSemiBold") == true, "Inter is a valid face")
	assert(events(fired) == "ThemeChanged", "a new face fires ThemeChanged")
	assert(ns.Tokens.Font("body"):match("Inter%-SemiBold%.ttf$"), "body text uses the chosen face")
	assert(ns.Tokens.Font("number"):match("SourceSans3%-Semibold%.ttf$"), "numbers keep the tabular face")
	assert(ns.Theme.SetFontFace("Comic") == false, "an unknown face is refused")
	assert(ns.Theme.SetFontFace("InterSemiBold") == true and #fired == 1, "the same face again fires nothing")
end

print("theme ok")
