-- test-module-font-inheritance.lua: inherited module fonts refresh with the kit while explicit stored paths survive every face change.
local function eq(got, want, message)
	assert(got == want, message .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function face(env, K, key)
	if K.Tokens.IsFontSet(key) then
		assert(K.Theme.SetTypeSet(key), "the bundled type set is available: " .. key)
		assert(K.Theme.SetFontFace(""), "the global face override can be cleared")
	else
		assert(K.Theme.SetFontFace(key), "the bundled face is available: " .. key)
	end
	env.RunTimers()
	eq(#env._errors, 0, "font refresh raised no errors: " .. tostring(env._errors[1]))
end

local function font(text, path, message)
	eq((text:GetFont()), path, message)
end

local function write(K, module, key, value)
	assert(K.Options.Write(module, key, value) ~= false, "write " .. module .. "." .. key)
end

do
	local A = dofile("Tools/regression/auras_env.lua")
	local env, K, ns = A.New({ layout = true })
	assert(K.Modules.Enable("Auras"))
	env.RunTimers()
	local entry = ns.Panel.Group("buffs").buttons[1]
	local explicit = K.Tokens.FontPath("InterSemiBold")
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(entry.timer, (K.Tokens.Font("timer")), "aura timers inherit the timer role")
		font(entry.count, (K.Tokens.Font("number")), "aura stacks inherit the number role")
	end
	write(K, "Auras", "timer.font", explicit)
	write(K, "Auras", "count.font", explicit)
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(entry.timer, explicit, "explicit aura timer font survives")
		font(entry.count, explicit, "explicit aura stack font survives")
	end
	write(K, "Auras", "timer.font", "")
	write(K, "Auras", "count.font", "")
	face(env, K, "SourceSans3Regular")
	font(entry.timer, (K.Tokens.Font("timer")), "reset aura timer inherits again")
	font(entry.count, (K.Tokens.Font("number")), "reset aura stack inherits again")
end
collectgarbage("collect")

do
	local G = dofile("Tools/regression/group_env.lua")
	local env, K, ns = G.New()
	G.SetRoster(env, "party", { { name = "Tester", class = "WARRIOR", health = 80, maxHealth = 100 } })
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local member
	ns.Unit.ForEach(function(f)
		if f.kind == "party" then
			member = member or f
		end
	end)
	assert(member, "a party member exists")
	local explicit = K.Tokens.FontPath("InterSemiBold")
	local nameDefault = ns.Settings.THEME_FONT
	local compact = ns.Settings.COMPACT_NAME_FONT
	local healthDefault = K.Tokens.FontPath("AlegreyaSansExtraBold")
	eq(ns.Settings.defaults.text.nameFont, nameDefault, "group names retain the staging theme sentinel")
	eq(compact, K.Tokens.FontPath("AlegreyaSansRegular"), "compact lanes retain the proven file")
	eq(ns.Settings.defaults.text.healthFont, healthDefault, "group health retains the staging default file")
	for _, key in ipairs({ "Folio", "Lumen", "SourceSans3Regular" }) do
		face(env, K, key)
		font(member.name, K.Tokens.IsFontSet(key) and compact or (K.Tokens.Font("names")), "group names retain the compact kit face or explicit global override")
		font(member.healthText, healthDefault, "group health intentionally keeps the original file")
	end
	write(K, "GroupFrames", "text.nameFont", explicit)
	write(K, "GroupFrames", "text.healthFont", explicit)
	for _, key in ipairs({ "Folio", "Lumen", "SourceSans3Regular" }) do
		face(env, K, key)
		font(member.name, explicit, "explicit group name font survives")
		font(member.healthText, explicit, "explicit group health font survives")
	end
	write(K, "GroupFrames", "text.nameFont", "")
	write(K, "GroupFrames", "text.healthFont", "")
	for _, key in ipairs({ "Folio", "Lumen", "SourceSans3Regular" }) do
		face(env, K, key)
		font(member.name, K.Tokens.IsFontSet(key) and compact or (K.Tokens.Font("names")), "reset group name restores the staging theme treatment")
		font(member.healthText, healthDefault, "reset group health restores the intentional Lumen default")
	end
end
collectgarbage("collect")

do
	local C = dofile("Tools/regression/chat_env.lua")
	local env, K, ns = C.New()
	C.Enable(env, K)
	local explicit = K.Tokens.FontPath("InterSemiBold")
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(env.ChatFrame1, (K.Tokens.Font("body")), "chat messages inherit the body role")
		font(env.ChatFrame1.editBox, (K.Tokens.Font("body")), "chat edit box inherits the body role")
	end
	write(K, "Chat", "font", explicit)
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(env.ChatFrame1, explicit, "explicit chat font survives")
		font(env.ChatFrame1.editBox, explicit, "explicit edit box font survives")
	end
	write(K, "Chat", "font", "")
	face(env, K, "SourceSans3Regular")
	font(env.ChatFrame1, (K.Tokens.Font("body")), "reset chat font inherits again")
	eq(ns.Frames.Fonts({ font = "", fontSize = 14, tabFontSize = 12 }), (K.Tokens.Font("body")), "preview resolves the current body font")
end
collectgarbage("collect")

do
	local B = dofile("Tools/regression/bags_env.lua")
	local env, K, ns = B.New({ bags = { [0] = { size = 1, items = { [1] = B.Item("potion") } } } })
	local slot = assert(ns.Inventory.Slot(0, 1))
	local explicit = K.Tokens.FontPath("InterSemiBold")
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(slot.count, (K.Tokens.Font("number")), "bag stacks inherit the number role")
		font(slot.level, (K.Tokens.Font("number")), "bag item levels inherit the number role")
	end
	write(K, "Bags", "font", explicit)
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(slot.count, explicit, "explicit bag font survives")
	end
	write(K, "Bags", "font", "")
	face(env, K, "SourceSans3Regular")
	font(slot.count, (K.Tokens.Font("number")), "reset bag font inherits again")
end
collectgarbage("collect")

do
	local CT = dofile("Tools/regression/combattext_env.lua")
	local env, K, ns = CT.New()
	CT.Enable(env, K)
	CT.Hit(env, "player", "WOUND", "", env.Secret(1200), 4)
	local number = assert(CT.Shown(ns)[1])
	local explicit = K.Tokens.FontPath("InterSemiBold")
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(number.text, (K.Tokens.Font("number")), "active combat numbers inherit the number role")
		eq(env.DAMAGE_TEXT_FONT, (K.Tokens.Font("number")), "world numbers inherit the number role")
	end
	write(K, "CombatText", "font", explicit)
	write(K, "CombatText", "worldFace", explicit)
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(number.text, explicit, "explicit combat font survives")
		eq(env.DAMAGE_TEXT_FONT, explicit, "explicit world font survives")
	end
	write(K, "CombatText", "font", "")
	write(K, "CombatText", "worldFace", "")
	face(env, K, "SourceSans3Regular")
	font(number.text, (K.Tokens.Font("number")), "reset combat font inherits again")
	eq(env.DAMAGE_TEXT_FONT, (K.Tokens.Font("number")), "reset world font inherits again")
	write(K, "CombatText", "worldFont", false)
	local original = env.DAMAGE_TEXT_FONT
	face(env, K, "Lumen")
	eq(env.DAMAGE_TEXT_FONT, original, "world-font follow toggle remains off")
end
collectgarbage("collect")

do
	local N = dofile("Tools/regression/nameplates_env.lua")
	local env, K, ns = N.New()
	N.Add(env, "nameplate1", { name = "Tester" })
	local plate = assert(ns.Plates.Get("nameplate1"))
	local explicit = K.Tokens.FontPath("InterSemiBold")
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(plate.healthText, (K.Tokens.Font("body")), "nameplate values preserve the effective body role")
	end
	write(K, "Nameplates", "font", explicit)
	for _, key in ipairs({ "SourceSans3Regular", "Lumen" }) do
		face(env, K, key)
		font(plate.healthText, explicit, "explicit nameplate font survives")
	end
	write(K, "Nameplates", "font", "")
	face(env, K, "SourceSans3Regular")
	font(plate.healthText, (K.Tokens.Font("body")), "reset nameplate font inherits again")
end

print("module font inheritance ok")
