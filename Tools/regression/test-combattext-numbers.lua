-- test-combattext-numbers.lua: KstyleUI_CombatText turns UNIT_COMBAT into animated numbers in the player's field, never touching a secret amount.
local CT = dofile("Tools/regression/combattext_env.lua")
local Hit, Shown, Text, Anim, Finish, LastCall = CT.Hit, CT.Shown, CT.Text, CT.Anim, CT.Finish, CT.LastCall

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function color(number)
	local r, g, b = LastCall(number.text, "SetTextColor")
	return r, g, b
end

local function isColor(number, K, token)
	local r, g, b = color(number)
	local er, eg, eb = K.Tokens.Color(token)
	return near(r, er) and near(g, eg) and near(b, eb)
end

local function enabled(opts)
	local env, K, ns = CT.New(opts)
	CT.Enable(env, K)
	return env, K, ns
end

-- Off until Enable: no events and no frames -------------------------------------------------------

do
	local env, K, ns = CT.New()
	assert(not K.Modules.IsRunning("CombatText"), "the module is off by default")
	local frames = #env._frames
	Hit(env, "player", "WOUND", "", env.Secret(1200), 4)
	assert(#env._frames == frames, "an event while off builds nothing")
	assert(ns.Module.pool == nil, "no pool exists while the module has never run")
	CT.Enable(env, K)
	assert(ns.Module.pool ~= nil, "Enable builds the pool")
end

-- The player's field is a Layout element ------------------------------------------------------------

do
	local env, K, ns = enabled()
	local el = K.Layout.Element("combattext.player")
	assert(el, "the field registers with Layout as combattext.player")
	assert(el.module == "CombatText", "the field belongs to the CombatText module")
	assert(el.opts.resizable, "the field is resizable")
	assert(el.label == K.Setup.Layouts.Element("combattext.player").label, "the field uses the setup's label")
	local default = K.Setup.Layouts.Default("combattext.player")
	local settings = K.Layout.Get("combattext.player")
	assert(settings.anchor == default.anchor and settings.x == default.x and settings.y == default.y, "the field starts at the DPS layout's position")
	assert(K.Layout.Live("combattext.player"), "the field is live while the module runs")
	Hit(env, "player", "WOUND", "", env.Secret(5), 1)
	local number = Shown(ns)[1]
	assert(number.frame:IsVisible(), "the number is visible while the field shows")
	assert(K.Layout.Set("combattext.player", "shown", "never"))
	assert(not number.frame:IsVisible(), "the field's shown rule hides its numbers too")
	assert(K.Layout.Set("combattext.player", "shown", nil))
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

-- Damage: the amount reaches AbbreviateNumbers untouched and the number takes the school's colour ---

do
	local env, K, ns = enabled()
	local amount = env.Secret(1234)
	Hit(env, "player", "WOUND", "", amount, 4)
	local shown = Shown(ns)
	assert(#shown == 1, "one hit shows one number, got " .. #shown)
	local number = shown[1]
	assert(Text(env, number) == "secret:short(1234)", "the text is AbbreviateNumbers of the secret amount, got " .. tostring(Text(env, number)))
	assert(isColor(number, K, "schoolFire"), "fire damage is the fire school's colour")
	assert(number.frame:IsShown(), "the number shows")
	local _, relative, relPoint = number.frame:GetPoint(1)
	assert(relative == K.Layout.Element("combattext.player").frame and relPoint == "BOTTOM", "the number starts at the bottom of the player's field")
	local path, size, flags = LastCall(number.text, "SetFont")
	assert(path == (K.Tokens.Font("number")) and size == 18 and flags == "OUTLINE", "the number uses the default font, size and outline")
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

-- Heals carry a plus sign; misses and absorbs show words -------------------------------------------

do
	local env, K, ns = enabled()
	Hit(env, "player", "HEAL", "", env.Secret(438), 2)
	local heal = Shown(ns)[1]
	assert(Text(env, heal) == "+secret:short(438)", "a heal shows +<amount>, got " .. tostring(Text(env, heal)))
	assert(isColor(heal, K, "friendly"), "a heal is the heal colour")

	Hit(env, "player", "DODGE", "", 0, 1)
	local dodge = Shown(ns)[2]
	assert(Text(env, dodge) == "Dodge", "a dodge shows the game's word, got " .. tostring(Text(env, dodge)))
	assert(isColor(dodge, K, "text"), "words are the miss colour")

	Hit(env, "player", "WOUND", "ABSORB", 0, 1)
	assert(Text(env, Shown(ns)[3]) == "Absorb", "a wound of 0 with ABSORB shows Absorb")
	Hit(env, "player", "WOUND", "", 0, 1)
	assert(Text(env, Shown(ns)[4]) == "Miss", "a plain wound of 0 shows Miss")
	Hit(env, "player", "WOUND", "ABSORB", env.Secret(55), 1)
	local guessed = Shown(ns)[4]
	assert(Text(env, guessed) == "Absorb", "a secret amount with ABSORB shows the word, since 0 cannot be ruled out")
	Hit(env, "player", "WOUND", "ABSORB", 300, 1)
	assert(Text(env, Shown(ns)[4]) == "short(300)", "a plain partial absorb shows its amount")
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

-- Critical hits grow and take the critical colour; glancing blows shrink ---------------------------

do
	local env, K, ns = enabled()
	Hit(env, "player", "WOUND", "", env.Secret(900), 1)
	Hit(env, "player", "WOUND", "CRITICAL", env.Secret(1900), 1)
	Hit(env, "player", "WOUND", "GLANCING", env.Secret(400), 1)
	local plain, crit, glance = Shown(ns)[1], Shown(ns)[2], Shown(ns)[3]
	assert(near(plain.frame:GetScale(), 1), "a plain hit has no emphasis")
	assert(near(crit.frame:GetScale(), 1.4), "a critical hit grows to the critical size, got " .. tostring(crit.frame:GetScale()))
	assert(crit.frame:GetScale() > glance.frame:GetScale() and glance.frame:GetScale() < 1, "a glancing blow is smaller")
	assert(isColor(crit, K, "neutral"), "critical damage takes the critical colour")
	assert(isColor(plain, K, "schoolPhysical"), "plain physical damage keeps the school colour")
	assert(Anim(crit, "pop").scaleFrom > 1, "a critical hit pops in")

	K.Options.Write("CombatText", "critColor", false)
	K.Options.Write("CombatText", "critScale", 1)
	Hit(env, "player", "WOUND", "CRITICAL", env.Secret(1900), 1)
	local calm = Shown(ns)[4]
	assert(near(calm.frame:GetScale(), 1) and isColor(calm, K, "schoolPhysical"), "a critical size of 1 and no critical colour turn the emphasis off")

	Hit(env, "player", "HEAL", "CRITICAL", env.Secret(700), 2)
	local healCrit = Shown(ns)[4]
	assert(isColor(healCrit, K, "friendly"), "a critical heal keeps the heal colour")
end

-- Secret flags, schools and events never reach a comparison ----------------------------------------

do
	local env, K, ns = enabled()
	Hit(env, "player", "WOUND", env.Secret("CRITICAL"), env.Secret(10), env.Secret(4))
	local hidden = Shown(ns)[1]
	assert(hidden and near(hidden.frame:GetScale(), 1), "a secret flag gives no emphasis")
	assert(isColor(hidden, K, "hostile"), "a secret school takes the damage colour")
	Hit(env, "player", env.Secret("HEAL"), "", env.Secret(10), 2)
	local unknown = Shown(ns)[2]
	assert(unknown and Text(env, unknown) == "secret:short(10)" and isColor(unknown, K, "text"), "a secret event shows the amount in the neutral colour")
	Hit(env, env.Secret("player"), "WOUND", "", env.Secret(10), 1)
	assert(#Shown(ns) == 2, "a secret unit shows nothing")
	Hit(env, "player", "ENERGIZE", "", 30, 0)
	Hit(env, "player", "WOUND", "", "lots", 1)
	assert(#Shown(ns) == 2, "power gains and amounts that are not numbers show nothing")
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

-- Settings: format, colours and kinds ------------------------------------------------------------

do
	local env, K, ns = enabled()
	K.Options.Write("CombatText", "format", "full")
	Hit(env, "player", "WOUND", "", env.Secret(12345), 8)
	assert(Text(env, Shown(ns)[1]) == "secret:full(12345)", "the full format uses BreakUpLargeNumbers")

	K.Options.Write("CombatText", "colorMode", "single")
	K.Options.Write("CombatText", "damageColor", { r = 0.1, g = 0.2, b = 0.3 })
	Hit(env, "player", "WOUND", "", env.Secret(5), 8)
	local r, g, b = color(Shown(ns)[2])
	assert(near(r, 0.1) and near(g, 0.2) and near(b, 0.3), "one colour for all damage when the school is not followed")

	K.Options.Write("CombatText", "heals", false)
	K.Options.Write("CombatText", "misses", false)
	Hit(env, "player", "HEAL", "", env.Secret(5), 2)
	Hit(env, "player", "PARRY", "", 0, 1)
	assert(#Shown(ns) == 2, "heals and misses can be switched off")
	K.Options.Write("CombatText", "damage", false)
	Hit(env, "player", "WOUND", "", env.Secret(5), 8)
	assert(#Shown(ns) == 2, "damage can be switched off")
	Hit(env, "target", "WOUND", "", env.Secret(5), 8)
	assert(#Shown(ns) == 2, "another unit has no field")
end

-- Throttling and pooling -----------------------------------------------------------------------------

do
	local env, K, ns = enabled()
	for i = 1, 5 do
		Hit(env, "player", "WOUND", "", env.Secret(i), 1)
	end
	local shown = Shown(ns)
	assert(#shown == 4, "the field shows at most four numbers at once, got " .. #shown)
	assert(Text(env, shown[1]) == "secret:short(2)" and Text(env, shown[4]) == "secret:short(5)", "the oldest number makes way for the newest")

	K.Options.Write("CombatText", "maxPerFrame", 2)
	Hit(env, "player", "WOUND", "", env.Secret(6), 1)
	assert(#Shown(ns) == 2, "a lower limit applies to the next number")

	local first = Shown(ns)[1]
	Finish(first)
	assert(#Shown(ns) == 1 and not first.frame:IsShown(), "a finished animation hides and releases its number")

	local frames = #env._frames
	for i = 1, 200 do
		Hit(env, "player", i % 2 == 0 and "WOUND" or "HEAL", "", env.Secret(i), 1)
		for _, number in ipairs(Shown(ns)) do
			if i % 3 == 0 then
				Finish(number)
			end
		end
	end
	assert(#env._frames == frames, "numbers come from the pool: " .. (#env._frames - frames) .. " frames were made")

	local lanes = {}
	K.Options.Write("CombatText", "maxPerFrame", 3)
	for i = 1, 3 do
		Hit(env, "player", "WOUND", "", env.Secret(i), 1)
	end
	for _, number in ipairs(Shown(ns)) do
		local _, _, _, x = number.frame:GetPoint(1)
		lanes[x] = true
	end
	local count = 0
	for _ in pairs(lanes) do
		count = count + 1
	end
	assert(count == 3, "three numbers in a row start in three lanes, got " .. count)
end

-- Animation styles, motion levels and the field's size --------------------------------------------

do
	local env, K, ns = enabled()
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	local rise = Anim(Shown(ns)[1], "move")
	assert(rise.offsetX == 0 and rise.offsetY > 0, "rise moves straight up")
	assert(near(rise.duration, 1.2), "the default duration is 1.2 seconds")
	local fade = Anim(Shown(ns)[1], "fade")
	assert(fade.fromAlpha == 1 and fade.toAlpha == 0 and near(fade.delay + fade.duration, 1.2), "the number fades out by the end")

	K.Layout.Set("combattext.player", "height", 360)
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	assert(Anim(Shown(ns)[2], "move").offsetY > rise.offsetY, "a taller field moves numbers further")

	K.Options.Write("CombatText", "style", "arc")
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	local a, b = Shown(ns)[3], Shown(ns)[4]
	assert(Anim(a, "move").offsetX ~= 0 and Anim(a, "fall").offsetY < 0, "arc moves sideways, up, then down")
	assert(Anim(a, "move").offsetX * Anim(b, "move").offsetX < 0, "arcs alternate sides")

	K.Options.Write("CombatText", "style", "pop")
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	assert(Anim(Shown(ns)[4], "pop").scaleFrom > 1, "pop starts large")

	K.Motion.SetLevel("reduced")
	Hit(env, "player", "WOUND", "CRITICAL", env.Secret(1), 1)
	local reduced = Shown(ns)[4]
	assert(Anim(reduced, "move").offsetY == 0 and Anim(reduced, "fall").offsetY == 0 and Anim(reduced, "pop").scaleFrom == 1, "reduced motion keeps numbers still")
	assert(Anim(reduced, "fade").toAlpha == 0, "reduced motion still fades")

	K.Motion.SetLevel("off")
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	local off = Anim(Shown(ns)[4], "fade")
	assert(off.duration < 0.1 and near(off.delay + off.duration, 1.2), "with motion off a number shows, then goes at once")
	assert(CT.Called(Shown(ns)[4].group, "Play"), "the group plays")
	K.Motion.SetLevel("full")
end

-- Font settings reach the next number --------------------------------------------------------------

do
	local env, K, ns = enabled()
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	K.Options.Write("CombatText", "size", 30)
	K.Options.Write("CombatText", "outline", "NONE")
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	local newest = Shown(ns)[2]
	local _, size, flags = LastCall(newest.text, "SetFont")
	assert(size == 30 and flags == "", "the new size and outline apply, got " .. tostring(size) .. " " .. tostring(flags))
	local ox, oy = LastCall(newest.text, "SetShadowOffset")
	assert(ox > 0 and oy < 0, "without an outline the number gets the soft shadow")

	local MISSING = "Interface\\AddOns\\Missing\\Gone.ttf"
	local pool = ns.Module.pool
	pool:ReleaseAll()
	for _, number in ipairs(pool.free) do
		local setFont = number.text.SetFont
		number.text.SetFont = function(self, path, ...)
			setFont(self, path, ...)
			return path ~= MISSING
		end
	end
	K.Options.Write("CombatText", "font", MISSING)
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	local shown = Shown(ns)
	local path = LastCall(shown[#shown].text, "SetFont")
	assert(path == (K.Tokens.Font("number")), "a font that does not load falls back to the number font, got " .. tostring(path))
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

-- Disable releases everything and stops the events ---------------------------------------------------

do
	local env, K, ns = enabled()
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	K.Modules.Disable("CombatText")
	assert(#Shown(ns) == 0, "Disable releases every number")
	assert(not K.Layout.Element("combattext.player").frame:IsShown(), "Disable hides the field")
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	assert(#Shown(ns) == 0, "no numbers after Disable")
	CT.Enable(env, K)
	Hit(env, "player", "WOUND", "", env.Secret(1), 1)
	assert(#Shown(ns) == 1 and K.Layout.Element("combattext.player").frame:IsShown(), "Enable again works")
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

print("combat text numbers ok")
