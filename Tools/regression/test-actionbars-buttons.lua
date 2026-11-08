-- test-actionbars-buttons.lua: the action buttons' states: icons, cooldowns, charges, counts, procs, usable and range shading, empty slots, drag and drop, tooltips, texts, accent, fade, the pet and stance bars and the preview.
local AB = dofile("Tools/regression/actionbars_env.lua")
local W = AB.W

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function new(opts)
	local env, K, ns = AB.New(opts)
	AB.Enable(env, K)
	return env, K, ns
end

-- The icon texture takes the action's texture file ID as the game gives it (the icon pack replaces the file the
-- client loads for it); an empty slot clears the icon.
do
	local env, K, ns = new()
	assert(K.Icons == nil, "there is no icon service to go through")
	AB.Slot(env, 2, { texture = 136048, type = "spell", id = 5 })
	local b = AB.Button(ns, "bar1", 2)
	assert(W.LastCall(b.icon, "SetTexture")[1] == 136048, "the file ID goes straight to the texture")
	AB.Slot(env, 2, nil)
	assert(W.LastCall(b.icon, "SetTexture")[1] == nil, "an empty slot shows no icon")
	assert(#env._errors == 0, AB.Errors(env))
end

-- The global cooldown alone never dims an icon or greys its rim: the module reads isOnGCD and tells the button.
do
	local env, K, ns = new()
	local cooldown = { name = "cd" }
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1, cooldown = cooldown })
	local gcd = true
	env.C_ActionBar.GetActionCooldown = function()
		return { isOnGCD = gcd }
	end
	local b = AB.Button(ns, "bar1", 1)
	env.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
	assert(W.LastCall(b.cooldown, "SetCooldownFromDurationObject")[1] == cooldown, "the swipe runs for the GCD")
	b.cooldown:Show()
	b.cooldown:GetScript("OnShow")(b.cooldown)
	local rr, rg, rb = K.Widgets.MixTokens("accent", 1, "textHover", 1, 0.15)
	assert(b.icon:GetVertexColor() == 1 and W.SameColor(b.chrome.inner[5], rr, rg, rb, 1), "the icon stays bright and the rim on the accent during the GCD")
	gcd = false
	env.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
	assert(W.Near(b.icon:GetVertexColor(), 0.4) and W.SameRGB(b.chrome.inner[5], K.Tokens.Color("text")), "a real cooldown dims the icon and greys the rim")
	-- Forever trusts isOnGCD only in response to SPELL_UPDATE_COOLDOWN, so that event refreshes the classification too.
	gcd = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(b.icon:GetVertexColor() == 1 and W.SameColor(b.chrome.inner[5], rr, rg, rb, 1), "the spell cooldown event re-reads isOnGCD and brightens a GCD-only button")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Cooldowns come from duration objects; charges add a recharge edge; counts and charges show as text.
do
	local env, _, ns = new()
	local cooldown, recharge = { name = "cd" }, { name = "charge" }
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1, cooldown = cooldown, count = "2", charges = { maxCharges = 2, currentCharges = 1, isActive = true }, chargeDuration = recharge })
	local b = AB.Button(ns, "bar1", 1)
	assert(W.LastCall(b.cooldown, "SetCooldownFromDurationObject")[1] == cooldown, "the cooldown sweep uses the duration object")
	assert(b.chargeCooldown and W.LastCall(b.chargeCooldown, "SetCooldownFromDurationObject")[1] == recharge, "a recharging charge gets the edge")
	assert(b.count:GetText() == "2", "the charge count")
	env._game.slots[1].charges = { maxCharges = 2, currentCharges = 2, isActive = false }
	env._game.slots[1].count = env.Secret("2")
	env.FireEvent("SPELL_UPDATE_CHARGES")
	env.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
	assert(#W.Calls(b.chargeCooldown, "Clear") >= 1, "full charges clear the edge")
	assert(env.issecretvalue(b.count:GetText()), "a secret count reaches the text untouched")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Proc glows follow SPELL_ACTIVATION_OVERLAY_GLOW_SHOW and HIDE for spells and spell macros.
do
	local env, _, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 100 })
	AB.Slot(env, 2, { texture = 2, type = "macro", id = 100, subType = "spell", text = "Burst" })
	AB.Slot(env, 3, { texture = 3, type = "spell", id = 200 })
	local b1, b2, b3 = AB.Button(ns, "bar1", 1), AB.Button(ns, "bar1", 2), AB.Button(ns, "bar1", 3)
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 100)
	assert(b1.proc and b2.proc and not b3.proc, "both buttons of spell 100 glow")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 100)
	assert(not b1.proc and not b2.proc)
	env._game.procs[200] = true
	AB.Slot(env, 3, { texture = 3, type = "spell", id = 200 })
	assert(b3.proc, "a proc already running shows when the button updates")
	env.FireEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", env.Secret(100))
	assert(#env._errors == 0, AB.Errors(env))
end

-- Usable and range shading: unusable greys out, lacking power tints, out of range tints; secrets never compare.
do
	local env, K, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1, usable = false })
	local b = AB.Button(ns, "bar1", 1)
	assert(b.usable == false and W.LastCall(b.icon, "SetDesaturated")[1] == true, "an unusable action is greyed")
	env._game.slots[1].usable, env._game.slots[1].noMana = false, true
	env.FireEvent("ACTION_USABLE_CHANGED", { { slot = 1, usable = false, noMana = true } })
	local power = K.Options.Read("ActionBars", "powerColor")
	assert(b.usable and near(b.tint[1], power.r) and near(b.tint[3], power.b), "lacking power tints with the power colour")
	env.FireEvent("ACTION_RANGE_CHECK_UPDATE", 1, false, true)
	local range = K.Options.Read("ActionBars", "rangeColor")
	assert(near(b.tint[1], range.r) and near(b.tint[2], range.g), "out of range tints with the range colour")
	env.FireEvent("ACTION_RANGE_CHECK_UPDATE", 1, true, true)
	env.FireEvent("ACTION_USABLE_CHANGED", { { slot = 1, usable = true, noMana = false } })
	assert(b.usable and near(b.tint[1], 1) and near(b.tint[2], 1), "in range and usable is untinted")
	env.FireEvent("ACTION_RANGE_CHECK_UPDATE", 1, env.Secret(false), env.Secret(true))
	env.FireEvent("ACTION_USABLE_CHANGED", { { slot = 1, usable = env.Secret(true), noMana = env.Secret(false) } })
	assert(env._game.rangeChecks[1] and env._game.rangeChecks[1] > 0, "range checks are on for shown slots")
	assert(#env._errors == 0, AB.Errors(env))
end

-- The current and auto-repeating actions are selected.
do
	local env, _, ns = new()
	AB.Slot(env, 4, { texture = 4, type = "spell", id = 4, current = true })
	local b = AB.Button(ns, "bar1", 4)
	assert(b.selected, "the current action is selected")
	env._game.slots[4].current = false
	env.FireEvent("ACTIONBAR_UPDATE_STATE")
	assert(not b.selected)
end

-- Empty buttons: shown as empty tiles by default; hidden by alpha when switched off, and shown while dragging.
do
	local env, K, ns = new()
	local b = AB.Button(ns, "bar1", 5)
	assert(W.LastCall(b, "SetAlpha")[1] == 1, "empty tiles show by default")
	K.Options.Write("ActionBars", "bar1.showEmpty", false)
	assert(W.LastCall(b, "SetAlpha")[1] == 0, "hidden empty buttons fade to nothing, which works in combat")
	env.FireEvent("ACTIONBAR_SHOWGRID")
	assert(W.LastCall(b, "SetAlpha")[1] == 1, "a dragged action shows every slot")
	env.FireEvent("ACTIONBAR_HIDEGRID")
	assert(W.LastCall(b, "SetAlpha")[1] == 0)
end

-- Drag and drop: out of combat only, and the lock needs the pick-up modifier.
do
	local env, _, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1 })
	local b = AB.Button(ns, "bar1", 1)
	b._scripts.OnDragStart(b, "LeftButton")
	assert(#env._game.picked == 0, "locked bars need the modifier")
	env._game.modified = true
	b._scripts.OnDragStart(b, "LeftButton")
	assert(env._game.picked[1] == 1, "the modifier picks up the action")
	env._game.modified, env._game.lockActionBars = false, false
	b._scripts.OnReceiveDrag(b)
	assert(env._game.placed[1] == 1, "dropping places on the slot")
	env.SetCombat(true)
	b._scripts.OnDragStart(b, "LeftButton")
	b._scripts.OnReceiveDrag(b)
	assert(#env._game.picked == 1 and #env._game.placed == 1 and #env._blocked == 0, "nothing is picked up or placed in combat")
	env.SetCombat(false)
end

-- Tooltips show the action on hover and follow the tooltip setting.
do
	local env, K, ns = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1 })
	local b = AB.Button(ns, "bar1", 1)
	W.Enter(b)
	assert(env.GameTooltip:GetOwner() == b and env.GameTooltip._calls[#env.GameTooltip._calls] == "SetAction:1")
	W.Leave(b)
	assert(env.GameTooltip:GetOwner() == nil)
	K.Options.Write("ActionBars", "tooltips", "never")
	W.Enter(b)
	assert(env.GameTooltip:GetOwner() == nil, "no tooltip when switched off")
	W.Leave(b)
	K.Options.Write("ActionBars", "tooltips", "noCombat")
	env.SetCombat(true)
	W.Enter(b)
	assert(env.GameTooltip:GetOwner() == nil, "no tooltip in combat")
	W.Leave(b)
	env.SetCombat(false)
end

-- Texts: keybind, count, macro name and cooldown numbers each switch on and off; fonts follow the text settings.
do
	local env, K, ns = new({
		setup = function(e)
			e._game.bindings.ACTIONBUTTON1 = { "1" }
		end,
	})
	AB.Slot(env, 1, { texture = 1, type = "macro", id = 7, text = "Burst", count = "3" })
	local b = AB.Button(ns, "bar1", 1)
	assert(b.macroText:GetText() == "" or b.macroText:GetText() == nil, "macro names are off by default")
	K.Options.Write("ActionBars", "bar1.macro", true)
	assert(b.macroText:GetText() == "Burst", "the macro's name")
	K.Options.Write("ActionBars", "bar1.hotkey", false)
	assert(not b.hotkey:IsShown(), "the keybind text hides")
	K.Options.Write("ActionBars", "bar1.count", false)
	assert(not b.count:IsShown())
	K.Options.Write("ActionBars", "bar1.cooldown", false)
	assert(W.LastCall(b.cooldown, "SetHideCountdownNumbers")[1] == true, "the cooldown numbers hide")
	K.Options.Write("ActionBars", "text.count.size", 15)
	K.Options.Write("ActionBars", "text.count.outline", "OUTLINE")
	local path, size, flags = b.count:GetFont()
	assert(size == 15 * K.Theme.FontScale() and flags == "OUTLINE" and type(path) == "string", "the count font follows its settings")
	K.Callbacks.Fire("ThemeChanged")
	size, flags = select(2, b.count:GetFont())
	assert(size == 15 * K.Theme.FontScale() and flags == "OUTLINE", "a theme change keeps the text settings")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Accent: buttons follow the interface accent, the class colour, or a custom colour.
do
	local env, K, ns = new()
	local b = AB.Button(ns, "bar1", 1)
	assert(b.accent == nil, "the interface accent by default")
	K.Options.Write("ActionBars", "accentColor", { r = 0.1, g = 0.2, b = 0.3 })
	K.Options.Write("ActionBars", "accent", "custom")
	assert(b.accent and near(b.accent[1], 0.1) and near(b.accent[3], 0.3), "a custom accent")
	K.Options.Write("ActionBars", "accent", "class")
	local r, g = K.Theme.ClassColor(K.Theme.Class())
	assert(b.accent and near(b.accent[1], r) and near(b.accent[2], g), "the class colour")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Mouseover fade: the bar rests at the faded opacity and fades in while the pointer is over any of its buttons.
do
	local env, K, ns = new()
	local bar = ns.bars.bar1
	K.Options.Write("ActionBars", "bar1.fadeAlpha", 0.2)
	K.Options.Write("ActionBars", "bar1.fade", true)
	W.Settle(env)
	assert(near(bar.header:GetAlpha(), 0.2), "faded at rest")
	W.Enter(bar.buttons[1])
	W.Settle(env)
	assert(near(bar.header:GetAlpha(), 1), "full while hovered")
	W.Leave(bar.buttons[1])
	W.Tick(env, 0.05)
	W.Tick(env, 0.05)
	assert(near(bar.header:GetAlpha(), 1), "crossing the gap between buttons does not start a fade")
	W.Enter(bar.buttons[2])
	env.RunTimers()
	W.Settle(env)
	assert(near(bar.header:GetAlpha(), 1), "moving between buttons does not flicker")
	W.Leave(bar.buttons[2])
	env.RunTimers()
	W.Settle(env)
	assert(near(bar.header:GetAlpha(), 0.2), "fades back after the pointer leaves")
	env.FireEvent("ACTIONBAR_SHOWGRID")
	W.Settle(env)
	assert(near(bar.header:GetAlpha(), 1), "a drag shows faded bars")
	env.FireEvent("ACTIONBAR_HIDEGRID")
	K.Options.Write("ActionBars", "bar1.fade", false)
	W.Settle(env)
	assert(near(bar.header:GetAlpha(), 1))
	assert(#env._errors == 0, AB.Errors(env))
end

-- The pet bar: pet actions, a pet-exists visibility driver, right-click autocast, and BONUSACTIONBUTTON keys.
do
	local env, _, ns = new({
		setup = function(e)
			e._game.bindings.BONUSACTIONBUTTON1 = { "CTRL-1" }
			e._game.petExists = true
			e._game.pet[1] = { name = "PET_ACTION_ATTACK", texture = "PET_ATTACK_TEXTURE", isToken = true, isActive = true }
			e._game.pet[4] = { name = "Bite", texture = 132278, spellID = 17253, autoCastAllowed = true, autoCastEnabled = true }
			e.PET_ATTACK_TEXTURE = "Interface\\Icons\\Ability_GhoulFrenzy"
		end,
	})
	local bar = ns.bars.pet
	assert(env.Driver(bar.header, "visibility") == "[@pet,exists] show; hide", "the pet bar shows while a pet exists")
	local attack, bite = bar.buttons[1], bar.buttons[4]
	assert(attack:GetAttribute("type") == "pet" and attack:GetAttribute("action") == 1)
	assert(W.LastCall(attack.icon, "SetTexture")[1] == env.PET_ATTACK_TEXTURE, "token icons resolve to their texture")
	assert(attack.selected, "the active command is selected")
	assert(bite.autocast:IsShown(), "autocast shows a mark")
	assert(bite:GetAttribute("type2") == "", "right-click casts nothing secure")
	AB.Click(env, bite, "RightButton", false)
	assert(env._game.autocastToggled[1] == 17253, "right-click toggles autocast")
	assert(AB.PressKey(env, "CTRL-1") and AB.Used(env) == "pet1", "the pet keybind")
	env._game.pet[4].autoCastEnabled = false
	env.SetCombat(true)
	env.FireEvent("PET_BAR_UPDATE")
	assert(not bite.autocast:IsShown() and #env._blocked == 0, "pet updates in combat are visual only")
	env.SetCombat(false)
	assert(#env._errors == 0, AB.Errors(env))
end

-- The stance bar: one button per form, cast by spell ID, the active form selected; new forms wait for combat to end.
do
	local env, _, ns = new({
		setup = function(e)
			e._game.forms = {
				{ texture = 132349, spellID = 2457, isActive = true },
				{ texture = 132341, spellID = 71 },
			}
			e._game.bindings.SHAPESHIFTBUTTON2 = { "F2" }
		end,
	})
	local bar = ns.bars.stance
	assert(bar.buttons[1]:IsShown() and bar.buttons[2]:IsShown() and not bar.buttons[3]:IsShown(), "two forms, two buttons")
	assert(near(bar.holder:GetWidth(), 2 * 30 + 3), "the bar fits its forms")
	assert(bar.buttons[1]:GetAttribute("type") == "spell" and bar.buttons[1]:GetAttribute("spell") == 2457)
	assert(bar.buttons[1].selected and not bar.buttons[2].selected, "the active form is selected")
	assert(AB.PressKey(env, "F2") and AB.Used(env) == "spell71")
	env.SetCombat(true)
	env._game.forms[3] = { texture = 132275, spellID = 2458 }
	env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
	assert(#env._blocked == 0, "a new form in combat waits: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	assert(bar.buttons[3]:IsShown() and bar.buttons[3]:GetAttribute("spell") == 2458, "and appears after combat")
	env._game.forms[2].spellID = 7376
	env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
	assert(bar.buttons[2]:GetAttribute("spell") == 7376, "a new rank of a form updates the button's spell")
	env._game.forms = {}
	env.FireEvent("UPDATE_SHAPESHIFT_FORMS")
	assert(env.Driver(bar.header, "visibility") == "hide", "a class with no forms has no stance bar")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Flyouts open KstyleUI's own secure flyout, in combat too, and never reach Blizzard's SpellFlyout.
do
	local env, _, ns = new({
		setup = function(e)
			e._game.flyouts[9] = {
				name = "Portals",
				slots = {
					{ spellID = 10059, name = "Portal: Stormwind" },
					{ spellID = 11416, name = "Portal: Ironforge", known = false },
					{ spellID = 3561, name = "Teleport: Stormwind" },
					{ spellID = 3562, name = "Teleport: Stormwind" },
				},
			}
			e._game.slots[1] = { texture = 135744, type = "flyout", id = 9 }
			e._game.slots[2] = { texture = 1, type = "spell", id = 1 }
		end,
	})
	local owner, plain = AB.Button(ns, "bar1", 1), AB.Button(ns, "bar1", 2)
	local flyout = ns.flyout
	assert(flyout and flyout.frame, "the flyout is built")
	assert(owner.flyoutArrow:IsShown() and not plain.flyoutArrow:IsShown(), "a flyout action shows its arrow")
	assert(not flyout.frame:IsShown(), "closed at first")
	env.SetCombat(true)
	AB.Click(env, owner, "LeftButton", true)
	assert(AB.Used(env) == nil, "the click does not use the flyout action through Blizzard's SpellFlyout")
	assert(flyout.frame:IsShown(), "the click opens KstyleUI's flyout")
	local first, second, third = flyout.buttons[1], flyout.buttons[2], flyout.buttons[3]
	assert(first:IsShown() and second:IsShown() and not third:IsShown(), "one button per known spell")
	assert(first:GetAttribute("type") == "spell" and first:GetAttribute("spell") == 10059 and second:GetAttribute("spell") == 3562,
		"the highest known rank of each spell")
	assert(W.LastCall(first.icon, "SetTexture")[1] == 1010059, "flyout icons come from the spells")
	AB.Click(env, owner, "LeftButton", false)
	assert(flyout.frame:IsShown(), "the release of the same click does not close it")
	-- The flyout tells its buttons when a spell's cooldown is only the global cooldown, as the action buttons do.
	local gcd, running = true, {}
	env.C_Spell.GetSpellCooldown = function()
		return { isOnGCD = gcd }
	end
	env.C_Spell.GetSpellCooldownDuration = function()
		return running
	end
	AB.Click(env, first, "LeftButton", true)
	AB.Click(env, first, "LeftButton", false)
	AB.Click(env, owner, "LeftButton", true)
	AB.Click(env, owner, "LeftButton", false)
	assert(flyout.frame:IsShown() and first.realCooldown == false, "a flyout opened during the GCD leaves its buttons ready")
	gcd = false
	AB.Click(env, first, "LeftButton", true)
	AB.Click(env, first, "LeftButton", false)
	AB.Click(env, owner, "LeftButton", true)
	AB.Click(env, owner, "LeftButton", false)
	assert(flyout.frame:IsShown() and first.realCooldown == true, "a real cooldown reaches the flyout buttons as one")
	assert(W.LastCall(first.cooldown, "SetCooldownFromDurationObject")[1] == running, "the swipe ran in both cases")
	env.C_Spell.GetSpellCooldown = nil
	env.C_Spell.GetSpellCooldownDuration = nil
	AB.Click(env, first, "LeftButton", true)
	assert(AB.Used(env) == "spell10059", "a flyout button casts its spell")
	AB.Click(env, first, "LeftButton", false)
	assert(not flyout.frame:IsShown(), "and the flyout closes")
	AB.Click(env, owner, "LeftButton", true)
	AB.Click(env, owner, "LeftButton", true)
	assert(not flyout.frame:IsShown(), "clicking the owner again closes it")
	AB.Click(env, plain, "LeftButton", true)
	assert(AB.Used(env) == 2, "an ordinary action still casts")
	assert(#env._blocked == 0, "the flyout makes no protected call in combat: " .. table.concat(env._blocked, ", "))
	env.SetCombat(false)
	assert(#env._errors == 0, AB.Errors(env))
end

-- The leave-vehicle button replaces Blizzard's, which hides with the main bar.
do
	local env, _, ns = new({
		setup = function(e)
			e._exits = 0
			e.CanExitVehicle = function()
				return e._canExit == true
			end
			e.VehicleExit = function()
				e._exits = e._exits + 1
			end
			e.UnitOnTaxi = function()
				return false
			end
		end,
	})
	local leave = ns.leaveButton
	assert(leave and not leave:IsShown(), "hidden while there is no vehicle")
	assert(leave:GetParent() == ns.bars.bar1.holder, "it sits in bar 1's element, so it follows bar 1's Layout scale, opacity and shown rule")
	env._canExit = true
	env.FireEvent("UNIT_ENTERED_VEHICLE", "player")
	assert(leave:IsShown(), "shown in a vehicle")
	W.Click(leave)
	assert(env._exits == 1, "a click leaves the vehicle")
	env._canExit = false
	env.FireEvent("UNIT_EXITED_VEHICLE", "player")
	assert(not leave:IsShown())
	assert(#env._errors == 0, AB.Errors(env))
end

-- Turning the module off releases every range check it asked for.
do
	local env, K = new()
	AB.Slot(env, 1, { texture = 1, type = "spell", id = 1 })
	assert(env._game.rangeChecks[1] == 1)
	K.Modules.Disable("ActionBars")
	assert(env._game.rangeChecks[1] == 0, "range checks stop with the module")
	K.Modules.Enable("ActionBars")
	assert(env._game.rangeChecks[1] == 1, "and start again with it")
	env.FireEvent("ACTIONBAR_SLOT_CHANGED", 1)
	assert(env._game.rangeChecks[1] == 1, "an update never asks twice")
	K.Options.Write("ActionBars", "bar1.enabled", false)
	assert(env._game.rangeChecks[1] == 0, "a bar switched off stops its range checks")
end

-- The live preview builds plain icon buttons from the kit and follows the settings.
do
	local env, K = new()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(400, 200)
	local frame = K.Options.Preview("ActionBars")(parent)
	assert(frame and type(frame.Refresh) == "function", "the preview has a Refresh")
	for _, button in ipairs(frame.buttons) do
		assert(button._template == nil, "preview buttons are not secure")
	end
	K.Options.Write("ActionBars", "bar1.size", 40)
	frame:Refresh()
	assert(near(frame.buttons[1]:GetWidth(), 40), "the preview follows the button size")
	assert(#env._errors == 0, AB.Errors(env))
end

print("action bar buttons ok")

-- Action buttons are primary icon buttons: their rim keeps the full accent whatever Widgets.SECONDARY_RIM says.
do
	local _, K, ns = new()
	local b = AB.Button(ns, "bar1", 1)
	assert(b.opts.primary == true, "an action button is a primary icon button")
	K.Widgets.SECONDARY_RIM = 0.5
	b:Paint()
	local rr, rg, rb = K.Widgets.IconRim()
	assert(W.SameColor(b.chrome.inner[5], rr, rg, rb, 1), "its rim keeps the full accent at any secondary strength")
	K.Widgets.SECONDARY_RIM = 1
end
