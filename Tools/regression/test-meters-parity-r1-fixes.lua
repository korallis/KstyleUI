-- test-meters-parity-r1-fixes.lua: the round 1 review's probes: the marker keeps row styling, Medallions name size, the preview's strip matches the live one, spell history never resizes another card and refills on resize, hidden displays do no work, history clears when off, motion, missing timers, the native window and the key heading.
local M = dofile("Tools/regression/meters_env.lua")
local G = dofile("Tools/regression/geometry.lua")
local env, K, n = M.New({ width = 1920, height = 1080, game = function(e) e._group.size = 5 end })
local function set(k, v) M.Write(env, K, k, v) end
local sources = {}
for i = 1, 5 do
	sources[i] = { name = "Player " .. i, classFilename = "WARRIOR", totalAmount = 6000 - i * 1000, amountPerSecond = 600 - i * 100,
		sourceGUID = "Player-" .. i, sourceDisplayType = 1, isLocalPlayer = i == 3 }
end
env._session = { combatSources = sources, maxAmount = 5000, totalAmount = 15000, durationSeconds = 10 }
M.Enable(env, K)
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers()
local d, t = n.Damage.list, n.Threat.list
local function cast(id) env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", id) end

-- Marking your row keeps the row's icon back and number separator.
assert(d.rows[3].back:IsShown() and d.rows[3].dot:IsShown(), "the row draws its icon back and separator")
set("damage.playerMarker", true)
assert(d.rows[3].marker:IsShown() and d.rows[3].back:IsShown() and d.rows[3].dot:IsShown(), "the first marker keeps the row's icon back and separator")
set("damage.playerMarker", false)

-- Name size works on Medallions with instrument names off.
set("instrumentNames", false)
local small = select(2, d.rows[1].name:GetFont())
set("damage.nameScale", 2)
assert(math.abs(select(2, d.rows[1].name:GetFont()) - 2 * small) < 0.01, "Medallions name size doubles at 200%")
set("damage.nameScale", 1)

-- The Options preview draws the live strip: direction, crop and appearance.
set("history.icons", true); set("history.bars", true); set("history.grow", "UP")
local p = env.CreateFrame("Frame", nil, env.UIParent); p:SetSize(900, 500); p:SetPoint("CENTER", env.UIParent, "CENTER")
local preview = n.Preview.Build(p)
local function step(s)
	local a, b = assert(G.Rect(s.icons[1].frame, s.holder)), assert(G.Rect(s.icons[2].frame, s.holder))
	return b.left - a.left, b.top - a.top
end
local lx, ly = step(n.History)
local px, py = step(assert(preview.strip, "the preview has a strip"))
assert(lx == 0 and ly > 0 and math.abs(px - lx) < 0.5 and math.abs(py - ly) < 0.5, "growth up stacks icons upwards in the preview as live: " .. px .. "," .. py)
assert(M.Last(preview.strip.icons[1].texture, "SetTexCoord")[1] == n.Get("damage.iconZoom"), "the preview crops icons as live")
env.IsInInstance = function() return false, "none" end
set("history.hideWorld", true); preview:Refresh()
assert(not preview.strip.holder:IsShown() and not preview.history.holder:IsShown(), "the preview follows the place rules")
set("history.hideWorld", false); preview:Refresh()
assert(preview.strip.holder:IsShown(), "and shows again")

-- Resizing spell history neither moves another card nor leaves it empty.
for i = 1, 10 do env._spells[i] = { name = "Spell " .. i, icon = i }; cast(i) end
local h = n.History.list
set("history.barCount", 10)
local dh = d.panel:GetHeight()
K.Layout.Update("meters.historyBars", { height = 40 }); env.RunTimers()
assert(d.panel:GetHeight() == dh and t.panel:GetHeight() == dh, "shrinking spell history leaves damage and threat alone: " .. d.panel:GetHeight())
K.Layout.Update("meters.historyBars", { height = 400 }); env.RunTimers()
assert(h.capacity >= 10 and h.count == 10, "growing spell history refills it at once: " .. h.count .. "/" .. h.capacity)

-- Turning both displays off forgets the old casts.
set("history.icons", false); set("history.bars", false); set("history.icons", true)
assert(#n.History.casts == 0 and not n.History.icons[1].frame:IsShown(), "re-enabled history starts empty")

-- Hidden displays query nothing, then paint once when shown.
set("history.icons", false); set("history.bars", true); set("history.hideWorld", true)
local reads, names = 0, 0
local texture, name = env.C_Spell.GetSpellTexture, env.C_Spell.GetSpellName
env.C_Spell.GetSpellTexture = function(...) reads = reads + 1; return texture(...) end
env.C_Spell.GetSpellName = function(...) names = names + 1; return name(...) end
cast(2)
assert(reads == 0 and names == 0, "a cast with every display hidden queries nothing: " .. reads .. "/" .. names)
set("history.hideWorld", false)
assert(h.panel:IsShown() and M.Last(h.rows[1].name, "SetText")[1]:upper() == "SPELL 2", "showing the card paints the casts it missed")
env.C_Spell.GetSpellTexture, env.C_Spell.GetSpellName = texture, name

-- Raid and PvP place rules.
for _, place in ipairs({ { "raid", "hideRaid" }, { "pvp", "hidePvP" }, { "arena", "hidePvP" } }) do
	env.IsInInstance = function() return true, place[1] end
	set("history." .. place[2], true); env.FireEvent("ZONE_CHANGED_NEW_AREA")
	assert(not h.panel:IsShown(), "hidden in " .. place[1])
	set("history." .. place[2], false)
end
env.IsInInstance = function() return false, "none" end; env.FireEvent("ZONE_CHANGED_NEW_AREA")

-- Card controls stay live for a lone spell history card.
set("damage.shown", false); set("threat.shown", false)
for _, row in ipairs(n.Schema()) do
	if row.key == "damage.panelAlpha" then assert(not row.disableWhen(K.Store.Module("Meters")), "the shared opacity control works for spell history alone") end
end

-- The show/hide key hides Blizzard's window in restyle mode and gives it back.
set("damage.shown", true); set("damage.mode", "skin")
local toggle = env.KstyleUI_MetersToggle
toggle._scripts.OnClick(toggle); env.RunTimers()
assert(n.windowsHidden and K.Safe.IsHidden(env.DamageMeter), "the key hides the restyled native meter")
toggle._scripts.OnClick(toggle); env.RunTimers()
assert(not n.windowsHidden and not K.Safe.IsHidden(env.DamageMeter), "the key gives the native meter back")
set("damage.mode", "window")

-- A hidden timer runs no ticker.
set("timer.shown", true); set("timer.toggle", true); set("timer.decimal", true); env.SetCombat(true)
toggle._scripts.OnClick(toggle); env.RunTimers()
local writes = M.Calls(n.Timer.text, "SetText"); env.RunTickers()
assert(not n.Timer.text:IsVisible() and not n.Timer.ticker and M.Calls(n.Timer.text, "SetText") == writes, "a hidden timer does no work")
toggle._scripts.OnClick(toggle); env.RunTimers()
assert(n.Timer.text:IsVisible() and n.Timer.ticker, "showing the timer starts its ticker")
env.SetCombat(false); set("timer.shown", false); set("timer.toggle", false)

-- Missing timer APIs leave defined states.
local ticker = env.C_Timer.NewTicker
env.C_Timer.NewTicker = nil
set("timer.shown", true); env.SetCombat(true); env.SetTime(env.GetTime() + 3)
assert(not n.Timer.text:IsVisible(), "without NewTicker the timer stays off instead of freezing")
env.SetCombat(false); env.C_Timer.NewTicker = ticker; set("timer.shown", false)
set("history.fade", 3)
local after = env.C_Timer.After
env.C_Timer.After = nil
local ok, err = pcall(n.History.OnEvent, n.History, "PLAYER_REGEN_ENABLED")
env.C_Timer.After = after
assert(ok, "without After the strip simply stays: " .. tostring(err))

-- Reduced motion stops the fly-in; full motion plays it from three icons away.
set("history.icons", true); set("history.fade", 0); set("history.anim", "fly")
assert(M.Last(n.History.move, "SetOffset")[2] == -90, "fly starts three icons back")
K.Motion.SetReducedMotion(true)
local plays = M.Calls(n.History.group, "Play"); cast(1)
assert(M.Calls(n.History.group, "Play") == plays, "reduced motion plays no fly-in")
K.Motion.SetReducedMotion(false); cast(1)
assert(M.Calls(n.History.group, "Play") == plays + 1, "full motion flies in")

-- The reset control is labelled and shows when the pointer enters through the title.
set("damage.resetButton", true); set("damage.resetHover", true)
assert(d.resetButton.label:GetText() == K.L["Reset"], "the reset control says Reset")
d.panel._mouseOver = true
d.titleHit._scripts.OnEnter(d.titleHit)
assert(d.resetButton:IsShown(), "entering through the title shows the reset control")

-- The meter keys have their heading without the action bars loaded.
assert(env.BINDING_HEADER_KSTYLEUI_ACTIONBARS == "KstyleUI", "the meter keys' heading is defined by the meters")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("meters parity round 1 fixes ok")
