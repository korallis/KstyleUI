-- test-auras-parity-filters.lua: EllesmereUI parity round 1 on the aura rows: a v0.2.8 profile keeps its rows, and each new option, switched on, writes, applies, previews and restores: Blizzard's aura categories, timed-only, buff spell lists, tooltips, the refresh mark, reverse swipe, the dispel-type icon, timer and stack positions, the seconds suffix, minutes-and-seconds timers, text colours and the opacity when hidden.
local A = dofile("Tools/regression/auras_env.lua")
local saved = { version = 4, profiles = { Default = { Auras = { enabled = true, timer = { format = "short" }, count = { size = 10 } } } }, characters = {} }
local env, K, ns = A.New({ saved = saved })
env.RunTimers()
local Model, Panel = ns.Model, ns.Panel
local function write(key, value) K.Options.Write("Auras", key, value); env.RunTimers() end
local function entryOf(name)
	local desc = Panel.Group(name)
	return desc, desc.buttons[1], desc.buttons[1].button._aura
end
local bdesc, buff, baura = entryOf("buffs")
local ddesc, debuff, daura = entryOf("debuffs")
local helpful = select(2, A.Container(env, "HELPFUL"))
local harmful = select(2, A.Container(env, "HARMFUL"))
local function calls(object, method) return #A.W.Calls(object, method) end

-- A v0.2.8 profile: the rows, filters, candidates, text and engine bindings are today's.
assert(helpful.filter == "HELPFUL" and harmful.filter == "HARMFUL", "a legacy profile keeps the plain filters")
assert(helpful.candidateFilters == nil and harmful.candidateFilters == nil, "a legacy profile adds no candidate filters")
assert(not buff.typeIcon and not debuff.typeIcon and not buff.cue and not debuff.cue, "a legacy profile makes no type icon or refresh mark")
assert(calls(buff.button, "SetMouseMotionEnabled") == 0 and baura.hideTooltipInCombat == nil, "a legacy profile leaves tooltips to the engine")
local plain = baura.timerOptions.textFormatter
assert(plain and rawget(plain, "breakpoints") == nil, "today's seconds formatter stays")
assert(buff.count._points[1][1] == "TOPRIGHT" and A.W.LastCall(buff.count, "SetJustifyH")[1] == "RIGHT", "the stack count stays top right")
assert(Model.HiddenAlpha(K.Store.Module("Auras")) == 0 and bdesc.host:IsShown() == bdesc.holder:IsShown(), "the rows hide with their element")

-- Show: Blizzard's categories become filter tokens on the row and its +N counter; All restores the plain filter.
write("buffs.show", "important")
write("debuffs.show", "crowdControl")
assert(helpful.filter == "HELPFUL|IMPORTANT" and harmful.filter == "HARMFUL|CROWD_CONTROL", "a category narrows each row's engine filter")
assert(bdesc.chip.ghost._groups.count.filter == "HELPFUL|IMPORTANT", "the +N counter counts the same category")
local valid = env.AuraUtil.IsValidFilterString
env.AuraUtil.IsValidFilterString = function() return false end
write("buffs.show", "external")
assert(helpful.filter == "HELPFUL", "a token the client refuses falls back to every buff")
env.AuraUtil.IsValidFilterString = valid
write("buffs.show", "all"); write("debuffs.show", "all")
assert(helpful.filter == "HELPFUL" and harmful.filter == "HARMFUL", "All restores the plain filters")

-- Only ones with a duration, and the buff spell lists, reach the engine's candidate filters and leave again.
write("buffs.timed", true); write("debuffs.timed", true)
assert(helpful.candidateFilters.maxDuration and harmful.candidateFilters.maxDuration, "timed-only hides permanent auras in the engine")
write("buffs.allowSpells", "774, 139"); write("buffs.blockSpells", "8936")
local c = helpful.candidateFilters
assert(c.includeSpellIDs[774] and c.includeSpellIDs[139] and c.excludeSpellIDs[8936] and c.maxDuration, "spell lists join timed-only")
assert(harmful.candidateFilters.includeSpellIDs == nil, "debuffs take no spell lists: the engine cannot match them on you")
write("buffs.timed", false); write("debuffs.timed", false); write("buffs.allowSpells", ""); write("buffs.blockSpells", "")
assert(helpful.candidateFilters == nil and harmful.candidateFilters == nil, "clearing them restores the plain rows")

-- Tooltips: out of combat or never, without touching right-click cancel; Always restores the engine's tooltips.
write("buffs.tooltips", "never")
assert(A.W.LastCall(buff.button, "SetMouseMotionEnabled")[1] == false and baura.cancel == "RightButtonUp", "no tooltips, and right-click still cancels")
write("buffs.tooltips", "noCombat")
assert(A.W.LastCall(buff.button, "SetMouseMotionEnabled")[1] == true and baura.hideTooltipInCombat == true, "tooltips only out of combat")
local before = calls(buff.button, "SetMouseMotionEnabled")
write("iconZoom", 0.08)
assert(calls(buff.button, "SetMouseMotionEnabled") == before, "an unrelated restyle does not reconfigure tooltips")
write("buffs.tooltips", "always")
assert(A.W.LastCall(buff.button, "SetMouseMotionEnabled")[1] == true and baura.hideTooltipInCombat == false, "Always restores the engine's tooltips")

-- The refresh mark: the crest debuffs' gold line, which the engine shows in the refresh window.
write("debuffs.refresh", true)
assert(debuff.cue and daura.pandemic[1] == debuff.cue and not debuff.cue:IsShown(), "the engine owns the refresh mark")
write("iconZoom", 0.07)
assert(#daura.pandemic == 1, "a restyle binds the mark once")
write("debuffs.refresh", false)
assert(#daura.pandemic == 0 and not debuff.cue:IsShown(), "off unbinds and hides the mark")
write("debuffs.refresh", true)
assert(#daura.pandemic == 1, "on again binds it again")
write("debuffs.refresh", false)

-- Reverse swipe stands alone: it makes no swipe, and with the swipe on it picks the fill direction.
write("buffs.swipeReverse", false)
assert(not buff.swipe, "reverse swipe alone makes no swipe")
write("buffs.swipe", true)
assert(A.W.LastCall(buff.swipe, "SetReverse")[1] == false, "the swipe fills the icon")
write("buffs.swipeReverse", true)
assert(A.W.LastCall(buff.swipe, "SetReverse")[1] == true, "on restores the clearing swipe")
write("buffs.swipe", false)

-- The dispel-type icon, with the dispel colour on or off, clear of the stack count; Hidden unbinds it.
local function bound(texture)
	for _, d in ipairs(daura.dispel) do if d.texture == texture then return d.options end end
end
write("debuffs.typeIcon", "TOPLEFT")
local icon = debuff.typeIcon
assert(icon and bound(icon).style == env.Enum.CustomAuraButtonDispelTypeTextureStyle.Icon and not bound(icon).showWithoutDispelType, "the engine draws the type icon")
assert(icon._points[1][1] == "TOPLEFT" and icon:GetWidth() > 9 and icon:GetWidth() < 11, "a 10-unit icon in the top left corner")
local count = Model.Count(K.Store.Module("Auras"))
assert(K.Widgets.Snap(debuff.skin, 1) + icon:GetWidth() < debuff.skin:GetWidth() - 2 * 0.6 * count.size - 2, "the type icon clears a two-digit stack count")
write("debuffs.dispel", false)
assert(bound(icon) and #daura.dispel == 1, "the type icon does not need the dispel colour")
write("debuffs.typeIconSize", 16)
assert(icon:GetWidth() > 15, "the size applies")
write("debuffs.typeIcon", "none")
assert(not bound(icon) and not icon:IsShown(), "Hidden unbinds and hides the icon")
write("debuffs.dispel", true); write("debuffs.typeIconSize", 10)

-- Timer and stack positions.
write("timer.position", "top")
assert(buff.timer._points[1][1] == "TOP" and buff.timer._points[1][3] == "TOP", "the timer on the icon's top edge")
assert(Model.TimerArea(Model.Timer(K.Store.Module("Auras"))) == 0, "a timer on the icon frees the lane under it")
write("timer.position", "center")
assert(buff.timer._points[1][1] == "CENTER", "the timer centred")
write("count.position", "BOTTOMLEFT")
local p = buff.count._points[1]
assert(p[1] == "BOTTOMLEFT" and p[4] > 0 and p[5] > 0 and A.W.LastCall(buff.count, "SetJustifyH")[1] == "LEFT", "the count inside the bottom left corner")
write("timer.position", "below"); write("count.position", "TOPRIGHT")
assert(buff.count._points[1][1] == "TOPRIGHT" and buff.timer._points[1][3] == "BOTTOM", "defaults restore both")

-- The seconds suffix and minutes-and-seconds: an engine rule formatter, cached per setting, mirrored by the preview.
write("timer.seconds", false)
local f = baura.timerOptions.textFormatter
assert(rawget(f, "breakpoints") and f:FormatNumber(24) == "24" and f:FormatNumber(120) == "2m" and f:FormatNumber(7200) == "2h", "no suffix on seconds only")
write("timer.precise", 5)
f = baura.timerOptions.textFormatter
assert(f:FormatNumber(245) == "4:05" and f:FormatNumber(59) == "59" and f:FormatNumber(300) == "5m", "minutes and seconds under five minutes")
write("iconZoom", 0.07)
assert(baura.timerOptions.textFormatter == f, "the rule formatter is cached")
assert(ns.Panel.RuleFormatter(Model.Timer(K.Store.Module("Auras"))) == f, "the preview takes the same formatter")
write("timer.seconds", true)
assert(baura.timerOptions.textFormatter:FormatNumber(24) == "24s" and baura.timerOptions.textFormatter:FormatNumber(245) == "4:05", "the suffix returns with precise timers")
write("timer.format", "decimal")
assert(baura.timerOptions.textFormatter:FormatNumber(2.45) == "2.4", "tenths stay under three seconds")
local create = env.C_StringUtil.CreateNumericRuleFormatter
env.C_StringUtil.CreateNumericRuleFormatter = nil
write("timer.precise", 7)
assert(baura.timerOptions.textFormatter ~= nil and rawget(baura.timerOptions.textFormatter, "breakpoints") == nil, "a client without rule formatters keeps the plain format")
env.C_StringUtil.CreateNumericRuleFormatter = create
write("timer.format", "short"); write("timer.precise", 0)
assert(baura.timerOptions.textFormatter == plain, "defaults restore today's format")

-- Text colours: custom colours colour the text and the timer's warning curve; off restores the kit's.
write("timer.color", { r = 1, g = 0.5, b = 0 }); write("timer.customColor", true)
write("count.color", { r = 0, g = 1, b = 0 }); write("count.customColor", true)
local tc, cc = A.W.LastCall(buff.timer, "SetTextColor"), A.W.LastCall(buff.count, "SetTextColor")
assert(tc[1] == 1 and tc[2] == 0.5 and cc[2] == 1, "custom colours apply")
local points = baura.timerOptions.textColor.curve.points
assert(points[#points].color.r == 1 and points[#points].color.g == 0.5, "the warning fades from the custom colour")
write("timer.customColor", false); write("count.customColor", false)
local tr, tg = K.Tokens.Color("timerText")
assert(A.W.LastCall(buff.timer, "SetTextColor")[1] == tr and A.W.LastCall(buff.timer, "SetTextColor")[2] == tg, "off restores the kit colour")

-- Opacity when hidden: the rows dim instead of hiding while their Shown rule hides them, and never while the module is off.
write("hiddenAlpha", 0.3)
bdesc.holder:Hide()
assert(bdesc.host:IsShown() and math.abs(bdesc.host:GetAlpha() - 0.3) < 1e-6, "a hidden row stays at the chosen opacity")
bdesc.holder:Show()
assert(bdesc.host:IsShown() and bdesc.host:GetAlpha() == bdesc.holder:GetAlpha(), "shown again, the row follows its element")
write("hiddenAlpha", 0)
bdesc.holder:Hide()
assert(not bdesc.host:IsShown(), "0 hides the row as before")
bdesc.holder:Show()
write("hiddenAlpha", 0.3)
K.Modules.Disable("Auras"); env.RunTimers()
assert(not bdesc.host:IsShown() and not ddesc.host:IsShown(), "a disabled module shows no faded rows")
K.Modules.Enable("Auras"); env.RunTimers()
write("hiddenAlpha", 0)

-- The live preview reflects the visible options.
for key, value in pairs({ ["debuffs.typeIcon"] = "TOPLEFT", ["buffs.refresh"] = true, ["timer.seconds"] = false, ["count.position"] = "BOTTOMLEFT" }) do write(key, value) end
local holder = env.CreateFrame("Frame", nil, K.Scale.Root()); holder:SetSize(280, 300)
local preview = ns.Preview.Build(holder)
assert(preview.debuffs[3].typeIcon:IsShown() and A.W.LastCall(preview.debuffs[3].typeIcon, "SetAtlas")[1] == "RaidFrame-Icon-DebuffMagic", "the preview draws the type icon")
assert(not preview.debuffs[1].typeIcon:IsShown(), "and none on a typeless debuff")
assert(preview.buffs[1].cue:IsShown() and not preview.buffs[2].cue:IsShown(), "the preview marks a refreshable buff")
assert(preview.buffs[4].timer:GetText() == "24" and preview.buffs[4].count._points[1][1] == "BOTTOMLEFT", "the preview text follows the settings")

-- A restricted edit waits for combat to end.
env.SetCombat(true); env._aurasSecret = true
write("debuffs.typeIcon", "BOTTOMRIGHT")
assert(debuff.typeIcon._points[1][1] == "TOPLEFT", "a restricted aura edit waits")
env._aurasSecret = false; env.SetCombat(false); env.FireEvent("PLAYER_REGEN_ENABLED"); env.RunTimers()
assert(debuff.typeIcon._points[1][1] == "BOTTOMRIGHT", "the edit applies when combat ends")
assert(#env._errors == 0 and K.ErrorCount() == 0, "the new options raise no errors: " .. tostring(env._errors[1]))
print("auras parity filters ok")
