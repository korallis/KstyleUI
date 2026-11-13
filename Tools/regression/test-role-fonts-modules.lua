-- test-role-fonts-modules.lua: an explicit role font reaches GroupFrames and UnitFrames, loses to an element font, survives their long-name fallbacks, and leaves default geometry and records alone.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local D = dofile("Tools/regression/databars_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local ROLE_FACE = "CinzelUnit"
local OTHER = "Interface\\AddOns\\OtherMedia\\Second.ttf"

local function member(ns, name)
	local found
	ns.Unit.ForEach(function(f)
		if f.unit == name then
			found = f
		end
	end)
	assert(found, "the roster draws " .. name)
	return found
end

local function uniform(ns, path, what)
	local size
	ns.Unit.ForEach(function(f)
		if f.kind == "party" and f.unit then
			local face, current = f.name:GetFont()
			eq(face, path, what .. ": every row has the face")
			assert(not size or W.Near(size, current), what .. ": every row has one size")
			size = current
		end
	end)
	return size
end

local function fits(K, ns, f, what)
	local text = f.name:GetText()
	local _, size = f.name:GetFont()
	assert(ns.Names.Width(f.name, text, size) <= f.nameWidth + 0.01, what .. ": the displayed name fits")
	assert(size >= K.Widgets.FontSize(f.name, f.nameFit.min) - 0.001, what .. ": fitting respects the existing floor")
end

-- GroupFrames: party names, in the captioned rows of KSTY-31's party card (KSTY-57's bare rows take names; see
-- test-groupframes-rows.lua).
do
	local Looks = dofile("Tools/regression/group_looks.lua")
	local env, K, ns = G.New({ saved = Looks.Saved(Looks.PARTY_CARD) })
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 72 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 60 },
	})
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local tank, shaman = member(ns, "party1"), member(ns, "party2")
	local compact = ns.Settings.COMPACT_NAME_FONT
	local names = K.Tokens.FontPath("AlegreyaSansRegular")
	eq(compact, names, "the compact constant is still Alegreya Sans Regular")
	eq(ns.Settings.THEME_FONT, "theme", "the follow sentinel is unchanged")
	eq(K.Store.Defaults("GroupFrames").text.nameFont, "theme", "the saved default is the sentinel, not a captured file")
	eq((tank.name:GetFont()), compact, "a captioned party deliberately keeps the compact face by default")
	local healthFace = (tank.healthText:GetFont())
	eq(healthFace, K.Tokens.FontPath("AlegreyaSansExtraBold"), "the old health default stays Alegreya Sans ExtraBold")
	local parts, caption = tank.parts, tank.classLine:GetText()
	local nameWidth, healthTop, roleLeft = parts.name.width, parts.health.top, parts.icons.role.left
	local originalSize = uniform(ns, compact, "default party")

	K.Options.Write("Appearance", "roleFontNames", ROLE_FACE)
	env.RunTimers()
	local roleFace = K.Tokens.FontPath(ROLE_FACE)
	eq((tank.name:GetFont()), roleFace, "an explicit names role is used, not the compact default")
	eq((shaman.name:GetFont()), roleFace, "the whole party uses it")
	uniform(ns, roleFace, "role party")
	eq(tank.classLine:GetText(), caption, "the fixed class label is untouched")
	eq(tank.parts.name.width, nameWidth, "no lane moved")
	eq(tank.parts.health.top, healthTop, "the health bar did not move")
	eq(tank.parts.icons.role.left, roleLeft, "the role icon did not move")
	eq((tank.healthText:GetFont()), healthFace, "health text keeps its own default face")
	fits(K, ns, tank, "role party")
	ns.Names.Set(tank, "Thaldrenwick")
	assert(tank.name:GetText() == "Thaldrenwick" or tank.name:GetText():find("...", 1, true), "a longer name is whole or abbreviated, never lost")
	eq((tank.name:GetFont()), roleFace, "a longer name does not swap the role face for the compact one")
	local longName = string.rep("Shadow", 10)
	ns.Names.Set(tank, longName)
	eq((tank.name:GetFont()), roleFace, "even an out-of-contract name keeps the role face")
	assert(tank.name:GetText():find("...", 1, true), "and is abbreviated like a custom-face lane")
	local _, size = tank.name:GetFont()
	assert(W.Near(size, K.Widgets.FontSize(tank.name, tank.nameFit.min)), "it stops at the existing floor")
	ns.Names.Set(tank, "Thaldren")

	K.Options.Write("GroupFrames", "text.nameFont", OTHER)
	env.RunTimers()
	eq((tank.name:GetFont()), OTHER, "an element font beats the role font")
	K.Options.Write("GroupFrames", "text.nameFont", ns.Settings.THEME_FONT)
	env.RunTimers()
	eq((tank.name:GetFont()), roleFace, "returning to the sentinel follows the role again")

	assert(K.Theme.SetFontFace("InterSemiBold"))
	env.RunTimers()
	eq((tank.name:GetFont()), roleFace, "a whole-interface font loses to the role font")
	K.Options.Write("Appearance", "roleFontNames", "")
	env.RunTimers()
	eq((tank.name:GetFont()), (K.Tokens.Font("names")), "clearing the role follows the whole-interface font")
	assert(K.Theme.SetFontFace(""))
	env.RunTimers()
	eq((tank.name:GetFont()), compact, "and then the compact kit default returns exactly")
	local _, restored = tank.name:GetFont()
	assert(W.Near(restored, originalSize), "at its original size")
	eq(tank.parts.name.width, nameWidth, "default geometry is unchanged after the round trip")
	eq(K.Store.Module("GroupFrames").text.nameFont, "theme", "the saved element value never captured a file")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- GroupFrames: raid names in a narrow lane take the party names' face (KSTY-60 item 11), and a role font still wins.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(5, function(i, m)
		if i == 1 then
			m.name = "Thaldrenwick"
		end
	end))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local f = member(ns, "raid1")
	eq((f.name:GetFont()), (K.Tokens.Font("names")), "the raid takes the party names' face by default (KSTY-60 item 11)")
	eq(f.name:GetText(), "Thaldrenwick", "the twelve-letter fixture stays whole")
	K.Options.Write("Appearance", "roleFontNames", ROLE_FACE)
	env.RunTimers()
	local roleFace = K.Tokens.FontPath(ROLE_FACE)
	eq((f.name:GetFont()), roleFace, "an explicit names role survives the compact lane")
	fits(K, ns, f, "role raid")
	assert(f.nameFit.kit == false and f.nativeName == false, "the lane is treated like an explicit face: no compact swap, distinct abbreviations")
	K.Options.Write("Appearance", "roleFontNames", "")
	env.RunTimers()
	eq((f.name:GetFont()), (K.Tokens.Font("names")), "clearing returns the names face")
	assert(f.nameFit.kit == true and f.nativeName == true, "the kit names face passes the name to the engine, as in the party")
	K.Options.Write("Appearance", "roleFontBody", ROLE_FACE)
	env.RunTimers()
	eq((f.name:GetFont()), (K.Tokens.Font("names")), "another role does not touch the names lane")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- UnitFrames: the long-name fallback keeps an explicit role font, like an explicit element font.
do
	local env, K, ns = U.New()
	env._textWidth = D.TextWidth
	local Frames, Settings = ns.Frames, ns.Settings
	local function size(text)
		local _, s = text:GetFont()
		return s
	end
	local focus = Frames.Get("focus").views[1]
	local role = Settings.Role("focus", "name")
	assert(role == "names" or role == "unit", "the focus name wears a name role: " .. tostring(role))
	local _, full = Settings.Font("focus", "name")
	local bodyPath, bodySize = K.Tokens.Font("body")
	local long = "Elunara Frostweaver"
	U.SetUnit(env, "focus", { name = long, level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
	env.FireEvent("UNIT_NAME_UPDATE", "focus")
	eq((focus.name:GetFont()), bodyPath, "by default a long name falls to the body face")
	assert(math.abs(size(focus.name) - bodySize) < 0.01, "at the body size")
	local defaultFont = Settings.Font("focus", "name")
	eq(defaultFont, K.Tokens.Font(role), "the default name face is the role's own")

	local key = "roleFont" .. role:sub(1, 1):upper() .. role:sub(2)
	K.Options.Write("Appearance", key, "InterSemiBold")
	local roleFace = K.Tokens.FontPath("InterSemiBold")
	eq((Settings.Font("focus", "name")), roleFace, "an explicit role font names the frame's text")
	U.SetUnit(env, "focus", { name = "Elunara", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
	env.FireEvent("UNIT_NAME_UPDATE", "focus")
	eq((focus.name:GetFont()), roleFace, "a short name wears the role font")
	assert(size(focus.name) <= full + 0.01 and size(focus.name) >= bodySize - 0.01, "at the frame's own size or the fitted one")
	U.SetUnit(env, "focus", { name = long, level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
	env.FireEvent("UNIT_NAME_UPDATE", "focus")
	eq((focus.name:GetFont()), roleFace, "a long name keeps the role font when it shrinks")
	assert(size(focus.name) <= full + 0.01 and size(focus.name) >= bodySize - 0.01, "it may shrink toward the body size, never below")
	assert(not focus.name:IsTruncated() or size(focus.name) <= bodySize + 0.01, "and truncates only after reaching the body size")
	local veryLong = "Elunara Frostweaver the Everlasting Moonshadow"
	U.SetUnit(env, "focus", { name = veryLong, level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
	env.FireEvent("UNIT_NAME_UPDATE", "focus")
	eq((focus.name:GetFont()), roleFace, "a very long name stops at the body size in the role font")
	assert(size(focus.name) >= bodySize - 0.01, "never below the body size")

	K.Options.Write("UnitFrames", "focus.fonts.name.font", OTHER)
	env.FireEvent("UNIT_NAME_UPDATE", "focus")
	eq((focus.name:GetFont()), OTHER, "an element font beats the role font")
	K.Options.Write("UnitFrames", "focus.fonts.name.font", Settings.THEME_FONT)
	K.Options.Write("Appearance", key, "")
	U.SetUnit(env, "focus", { name = long, level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
	env.FireEvent("UNIT_NAME_UPDATE", "focus")
	eq((focus.name:GetFont()), bodyPath, "clearing the role returns the default long-name fallback")
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
end

print("role fonts modules ok")
