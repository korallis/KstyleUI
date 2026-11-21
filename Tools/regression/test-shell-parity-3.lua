-- test-shell-parity-3.lua: the third batch of shell options keeps its defaults, writes, applies, reverses and loads v0.2.8-shaped profiles.
local function saved(module, settings)
	return { version = 42, profiles = { Default = { [module] = settings } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function write(env, K, module, key, value)
	assert(K.Options.Write(module, key, value) ~= false, module .. "." .. key .. " must write")
	env.RunTimers()
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local T = dofile("Tools/regression/tooltips_env.lua")
	local afk, dnd, combat, boss, auras = false, false, false, false, {}
	local env, K, ns = T.New({ saved = saved("Tooltips", { enabled = true, iconSize = 28 }), setup = function(e)
		e.UnitTokenFromGUID = function() return "mouseover" end
		e.UnitIsPlayer = function() return true end
		e.UnitIsAFK = function() return afk end
		e.UnitIsDND = function() return dnd end
		e.CHAT_FLAG_AFK, e.CHAT_FLAG_DND = "<AFK>", "<DND>"
		e.InCombatLockdown = function() return combat end
		e.C_InstanceEncounter = { IsEncounterInProgress = function() return boss end }
		e.C_Secrets = { ShouldAurasBeSecret = function() return false end }
		e.C_UnitAuras = { GetAuraDataByIndex = function(_, i) return auras[i] end }
		e.C_MountJournal = {
			GetMountFromSpell = function(spell) return spell == 32292 and 7 or nil end,
			GetMountInfoByID = function(id) return id == 7 and "Swift Purple Gryphon" or nil end,
		}
	end })
	K.Modules.Enable("Tooltips")
	local tip = env.GameTooltip
	local function hover()
		tip:ClearLines()
		tip:SetOwner(env.UIParent, "ANCHOR_NONE")
		tip:AddLine("Valerin")
		T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Unit, guid = "Player-1-1" })
		T.BlizzardShow(tip, true)
		return T.Lines(tip)
	end
	local function mount(lines)
		for _, line in ipairs(lines) do if line[1] == K.L["Mount"] then return line[2] end end
	end
	local s = K.Store.Module("Tooltips")
	assert(s.iconSize == 28 and ns.Settings.Get("show") == "always" and ns.Settings.Get("peekKey") == "SHIFT")
	assert(not ns.Settings.Get("awayTag") and not ns.Settings.Get("mountLine"), "new extras stay off")
	afk, combat, boss, auras = true, true, true, { { spellId = 32292 } }
	local lines = hover()
	assert(lines[1][1] == "Valerin" and not mount(lines) and tip:IsShown(), "defaults keep today's tooltip")
	local get, read = ns.Settings.Get, {}
	ns.Settings.Get = function(key) read[key] = true; return get(key) end
	T.BlizzardShow(tip, true)
	ns.Settings.Get = get
	assert(not read.show and not read.peekKey, "a default tooltip reads no visibility setting as it opens")
	local preview = K.Options.Preview("Tooltips")(env.CreateFrame("Frame", nil, K.Scale.Root()))
	local title, ride = preview.unit.rows[1].left, preview.unit.rows[6]
	assert(title:GetText() == "Valerin" and not ride.left:IsShown(), "the preview keeps today's unit sample")

	write(env, K, "Tooltips", "awayTag", true)
	write(env, K, "Tooltips", "mountLine", true)
	preview:Refresh()
	assert(title:GetText() == "Valerin <AFK>" and ride.left:IsShown() and ride.right:GetText() == K.L["Swift Brown Wolf"], "the preview shows the away tag and mount line")
	lines = hover()
	assert(lines[1][1] == "Valerin <AFK>", tostring(lines[1][1]))
	assert(mount(lines) == "Swift Purple Gryphon")
	afk, dnd = false, true
	assert(hover()[1][1] == "Valerin <DND>")
	env.UnitIsDND = function() return env.Secret(true) end
	auras = { { spellId = env.Secret(32292) } }
	lines = hover()
	assert(lines[1][1] == "Valerin" and not mount(lines), "secret away state and aura ids stay unread")
	auras = { { spellId = 1459 }, { spellId = 32292 } }
	assert(mount(hover()) == "Swift Purple Gryphon", "the mount is found past other auras")
	env.C_Secrets = { ShouldAurasBeSecret = function() return true end }
	assert(not mount(hover()), "secret auras add no mount line")
	env.C_Secrets = nil
	assert(not mount(hover()), "without the secrecy predicate combat reads no auras")
	combat = false
	assert(mount(hover()) == "Swift Purple Gryphon", "and out of combat it does")
	combat = true
	env.C_MountJournal = nil
	assert(not mount(hover()), "a missing mount journal adds no line")

	write(env, K, "Tooltips", "show", "outOfCombat")
	hover()
	assert(not tip:IsShown(), "combat hides the tooltip")
	env._modifiers.shift = true
	hover()
	assert(tip:IsShown(), "the peek key shows it")
	write(env, K, "Tooltips", "peekKey", "none")
	hover()
	assert(not tip:IsShown(), "no peek key keeps it hidden")
	env._modifiers.shift = false
	combat = false
	hover()
	assert(tip:IsShown(), "out of combat it shows")
	env.FireEvent("PLAYER_REGEN_DISABLED")
	assert(not tip:IsShown(), "entering combat hides an open tooltip before lockdown starts")
	env.InCombatLockdown = function() return env.Secret(true) end
	hover()
	assert(tip:IsShown(), "a secret combat state shows the tooltip")
	write(env, K, "Tooltips", "show", "outOfBoss")
	hover()
	assert(not tip:IsShown(), "a boss fight hides it")
	boss = false
	hover()
	assert(tip:IsShown())
	boss = true
	env.FireEvent("ENCOUNTER_START")
	assert(not tip:IsShown(), "a boss pull hides an open tooltip")
	write(env, K, "Tooltips", "show", "never")
	hover()
	assert(not tip:IsShown(), "never hides it")
	write(env, K, "Tooltips", "show", "always")
	write(env, K, "Tooltips", "awayTag", false)
	write(env, K, "Tooltips", "mountLine", false)
	lines = hover()
	assert(tip:IsShown() and lines[1][1] == "Valerin", "turning the options off restores today's tooltip")
	clean(env, K)
end

do
	local Q = dofile("Tools/regression/qol_env.lua")
	local accepted, fighting, boss, delay, box = 0, false, false, 0, {}
	local env, K, ns = Q.New({ saved = saved("QoL", { enabled = true, questModifier = "CTRL" }), setup = function(e)
		e.DELETE_ITEM_CONFIRM_STRING = "DELETE"
		box.SetText = function(self, text) self.text = text end
		e.StaticPopup_FindVisible = function(which) return which == "DELETE_GOOD_ITEM" and { GetEditBox = function() return box end } or nil end
		e.AcceptResurrect = function() accepted = accepted + 1 end
		e.InCombatLockdown = function() return fighting end
		e.C_InstanceEncounter = { IsEncounterInProgress = function() return boss end }
		e.GetCorpseRecoveryDelay = function() return delay end
	end })
	Q.Enable(env, K)
	assert(K.Store.Module("QoL").questModifier == "CTRL")
	assert(not ns.Get("autoDelete") and not ns.Get("autoResurrect") and ns.defaults.combatResurrect == nil)
	env.FireEvent("DELETE_ITEM_CONFIRM", "Thunderfury", 5, 1, 0)
	env.FireEvent("RESURRECT_REQUEST", "Mender")
	env.RunTimers()
	assert(box.text == nil and accepted == 0, "defaults leave both popups to the player")

	write(env, K, "QoL", "autoDelete", true)
	env.FireEvent("DELETE_ITEM_CONFIRM", "Thunderfury", 5, 1, 0)
	assert(box.text == nil, "the word waits for Blizzard's popup")
	env.RunTimers()
	assert(box.text == "DELETE")
	local timer = env.C_Timer
	env.C_Timer, box.text = {}, nil
	env.FireEvent("DELETE_ITEM_CONFIRM", "Thunderfury", 5, 1, 0)
	env.C_Timer = timer
	assert(box.text == "DELETE" and K.ErrorCount() == 0, "without C_Timer.After the word fills at once")
	write(env, K, "QoL", "autoResurrect", true)
	env.FireEvent("RESURRECT_REQUEST", "Mender")
	assert(accepted == 1, "out of combat the offer is taken")
	fighting = true
	env.FireEvent("RESURRECT_REQUEST", "Mender")
	assert(accepted == 1, "in combat the offer waits for the player, whoever casts it")
	fighting = env.Secret(false)
	env.FireEvent("RESURRECT_REQUEST", "Mender")
	assert(accepted == 1, "a secret combat state waits for the player")
	fighting, boss = false, true
	env.FireEvent("RESURRECT_REQUEST", "Mender")
	assert(accepted == 1, "dead and out of lockdown in a boss fight, the offer waits for the player")
	local encounter = env.C_InstanceEncounter
	env.C_InstanceEncounter, boss = nil, false
	env.FireEvent("RESURRECT_REQUEST", "Mender")
	assert(accepted == 1, "without the encounter API the offer waits for the player")
	env.C_InstanceEncounter = encounter
	fighting, delay = false, 30
	env.FireEvent("RESURRECT_REQUEST", "Mender")
	assert(accepted == 1, "a recovery delay leaves the popup's countdown")
	write(env, K, "QoL", "autoDelete", false)
	write(env, K, "QoL", "autoResurrect", false)
	box.text, delay = nil, 0
	env.FireEvent("DELETE_ITEM_CONFIRM", "Thunderfury", 5, 1, 0)
	env.FireEvent("RESURRECT_REQUEST", "Mender")
	env.RunTimers()
	assert(box.text == nil and accepted == 1, "turning off stops both helpers")
	clean(env, K)
end

do
	local D = dofile("Tools/regression/databars_env.lua")
	local env, K, ns, game = D.New({ saved = saved("DataBars", { enabled = true, strip = { clock24 = false } }) })
	assert(K.Store.Module("DataBars").strip.clock24 == false and K.Store.Module("DataBars").strip.money == "full")
	assert(ns.Format.Money(123456789, "short") == "12.3Kg" and ns.Format.Money(1438217, "short") == "143g" and ns.Format.Money(4321, "short") == "43s 21c")
	game.money = 123456789
	write(env, K, "DataBars", "strip.money", "short")
	assert(ns.Strip.view.items.gold.value:GetText() == "12.3Kg", tostring(ns.Strip.view.items.gold.value:GetText()))
	write(env, K, "DataBars", "strip.money", "gold")
	assert(ns.Strip.view.items.gold.value:GetText() == "12,345g", tostring(ns.Strip.view.items.gold.value:GetText()))
	clean(env, K)
end

do
	local B = dofile("Tools/regression/bags_env.lua")
	local env, K, ns = B.New({ saved = saved("Bags", { enabled = true, columns = 7 }), bags = { [0] = { size = 4, items = { B.Item("potion") } } }, setup = function(e)
		e.CharacterFrame = e.CreateFrame("Frame", "CharacterFrame", e.UIParent)
		e.CharacterFrame:Hide()
	end })
	env.RunTimers()
	local Inventory, character = ns.Inventory, env.CharacterFrame
	local function shut()
		character:Hide()
		local script = character:GetScript("OnHide")
		if script then script(character) end
	end
	assert(K.Store.Module("Bags").columns == 7 and not ns.Settings.Get("characterBags"))
	character:Show()
	assert(not Inventory.IsOpen() and not character:GetScript("OnShow"), "by default the character window leaves bags alone, unhooked")
	shut()
	write(env, K, "Bags", "characterBags", true)
	character:Show()
	assert(Inventory.IsOpen(), "the character window opens the bags")
	shut()
	assert(not Inventory.IsOpen(), "and closes the bags it opened")
	character:Show()
	env.ToggleAllBags()
	env.RunTimers()
	env.ToggleAllBags()
	env.RunTimers()
	shut()
	assert(Inventory.IsOpen(), "bags closed and reopened by hand stay open")
	env.ToggleAllBags()
	env.RunTimers()
	env.ToggleAllBags()
	env.RunTimers()
	character:Show()
	shut()
	assert(Inventory.IsOpen(), "bags the player opened stay open")
	env.ToggleAllBags()
	env.RunTimers()
	character:Show()
	write(env, K, "Bags", "characterBags", false)
	shut()
	assert(Inventory.IsOpen(), "turning the option off leaves the bags it opened to the player")
	env.ToggleAllBags()
	env.RunTimers()
	character:Show()
	assert(not Inventory.IsOpen(), "turning off stops following the character window")
	clean(env, K)
end

print("shell parity batch 3 ok: eight options keep defaults, apply, reverse and keep v0.2.8 settings")
