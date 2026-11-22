-- test-auras-parity-r2.lua: EllesmereUI parity round 2 on the aura rows: a v0.2.8 profile builds today's two rows only, and each new option, switched on, writes, applies, previews and restores: the extra buff and debuff rows (their own element, filter and size, built lazily, switched after combat, gone when off), the row glow, the nine on-icon anchors for timers, stack counts and type icons, with texts that share an anchor kept apart.
local A = dofile("Tools/regression/auras_env.lua")
local saved = { version = 4, profiles = { Default = { Auras = { enabled = true, timer = { format = "short" }, count = { size = 10 } } } }, characters = {} }
local env, K, ns = A.New({ saved = saved })
env.RunTimers()
local Model, Panel, Layouts = ns.Model, ns.Panel, K.Setup.Layouts
local function write(key, value) K.Options.Write("Auras", key, value); env.RunTimers() end
local function calls(object, method) return #A.W.Calls(object, method) end
local function endCombat() env._aurasSecret = false; env.SetCombat(false); env.FireEvent("PLAYER_REGEN_ENABLED"); env.RunTimers() end
local buffs, debuffs = Panel.Group("buffs"), Panel.Group("debuffs")
local buff, debuff = buffs.buttons[1], debuffs.buttons[1]

-- A v0.2.8 profile: two rows, no extra container or element, no glow, and the presets keep the extra rows off.
assert(#A.Rows(env) == 2 and not Panel.Group("extraBuffs") and not Panel.Group("extraDebuffs"), "a legacy profile builds today's two rows")
assert(not K.Layout.Element("auras.extraBuffs") and not K.Layout.Element("auras.extraDebuffs"), "and registers no extra element")
assert(not buff.glow and not debuff.glow, "and draws no glow")
for _, preset in ipairs(Layouts.Names()) do
	assert(Layouts.Shown(preset, "auras.extraBuffs") == false and Layouts.Shown(preset, "auras.extraDebuffs") == false, preset .. " keeps the extra rows off")
end

-- Show this row: the extra buff row is built on its own element, filter and size, beside the map under the debuffs.
local buffSize, buffFilter = buff.button:GetWidth(), select(2, A.Container(env, "HELPFUL")).filter
write("extraBuffs.enabled", true)
local extra = Panel.Group("extraBuffs")
local _, important = A.Container(env, "HELPFUL|IMPORTANT")
assert(extra and not extra.off and extra.host:IsShown() and important, "the extra buff row shows Blizzard's important buffs")
assert(K.Layout.Element("auras.extraBuffs") and K.Layout.Live("auras.extraBuffs"), "on its own live element")
local place, under = Layouts.Default("auras.extraBuffs"), Layouts.Default("auras.debuffs")
assert(place.anchor == "TOPRIGHT" and place.x == under.x and place.y < under.y, "right-aligned under the debuff row")
local eb = extra.buttons[1]
assert(eb and math.abs(eb.skin:GetWidth() - 36) < 1 and not eb.dispel, "with 36-unit buff tiles")
assert(buff.button:GetWidth() == buffSize and select(2, A.Container(env, "HELPFUL")).filter == buffFilter, "the buff row keeps its size and filter")

-- Independent settings: the extra row's filters, spell lists and size leave the buff row alone, and the other way round.
write("extraBuffs.show", "all"); write("extraBuffs.allowSpells", "774"); write("extraBuffs.iconSize", 40)
local _, extraGroup = A.Container(env, "HELPFUL", 2)
assert(extraGroup.candidateFilters.includeSpellIDs[774] and select(2, A.Container(env, "HELPFUL")).candidateFilters == nil, "the extra row's spell list is its own")
assert(math.abs(eb.skin:GetWidth() - 40) < 1 and buff.button:GetWidth() == buffSize, "and so is its size")
write("buffs.show", "external")
assert(extraGroup.filter == "HELPFUL", "the buff row's Show leaves the extra row's filter")
write("buffs.show", "all"); write("extraBuffs.allowSpells", ""); write("extraBuffs.iconSize", 36); write("extraBuffs.show", "important")

-- The extra debuff row: crowd control on debuff tiles with dispel plates; it needs no other row's option.
write("extraDebuffs.enabled", true)
local extraD = Panel.Group("extraDebuffs")
assert(select(2, A.Container(env, "HARMFUL|CROWD_CONTROL")) and extraD.buttons[1].dispel and extraD.host:IsShown(), "the extra debuff row shows crowd control with dispel plates")

-- A switch in combat waits for combat to end; off hides the row and its element, and the opacity when hidden never revives it.
local rows = #env._containers
env.SetCombat(true)
write("extraDebuffs.enabled", false)
assert(extraD.host:IsShown() and not extraD.off, "a switch in combat waits")
endCombat()
assert(extraD.off and not extraD.host:IsShown() and not K.Layout.Live("auras.extraDebuffs"), "and lands when combat ends")
write("hiddenAlpha", 0.3)
extraD.holder:Show()
assert(not extraD.host:IsShown(), "an off row stays hidden at any opacity and Shown rule")
write("hiddenAlpha", 0)
write("extraDebuffs.enabled", true)
assert(#env._containers == rows and extraD.host:IsShown() and K.Layout.Live("auras.extraDebuffs"), "on again reuses the row it built")
K.Modules.Disable("Auras"); env.RunTimers()
assert(not extra.host:IsShown() and not extraD.host:IsShown(), "a disabled module hides the extra rows")
K.Modules.Enable("Auras"); env.RunTimers()
assert(extra.host:IsShown() and extraD.host:IsShown(), "and brings them back")
assert(buffs.host:IsShown() and A.Hidden(env, env.BuffFrame) and A.Hidden(env, env.DebuffFrame), "the extra rows leave Blizzard's frames and the main rows alone")

-- The glow: the kit's selection glow, accent on buffs and hostile on debuffs, shown once per change and hidden by off.
write("debuffs.glow", true); write("buffs.glow", true)
assert(debuff.glow and debuff.glow.holder:IsShown() and debuff.glow.colorName == "hostile", "debuffs glow hostile")
assert(buff.glow and buff.glow.holder:IsShown() and buff.glow.colorName == "accent" and not eb.glow, "buffs glow in the accent, the extra row does not")
local shows = calls(debuff.glow.holder, "Show")
write("iconZoom", 0.08)
assert(calls(debuff.glow.holder, "Show") == shows, "an unrelated restyle does not show the glow again")
env.SetCombat(true); env._aurasSecret = true
local placed = calls(buff.glow.slice[1], "SetPoint")
buff.glow:Restyle()
assert(calls(buff.glow.slice[1], "SetPoint") == placed, "the glow's own restyle waits while auras are secret")
endCombat()
assert(calls(buff.glow.slice[1], "SetPoint") > placed, "and lands when combat ends")
write("debuffs.glow", false); write("buffs.glow", false); write("iconZoom", 0.07)
assert(not debuff.glow.holder:IsShown() and not buff.glow.holder:IsShown(), "off hides the glow")

-- Timer corners and side midpoints: the timer leaves the lane; a stack count sharing its anchor steps a line toward the middle.
write("timer.position", "TOPRIGHT")
local tp, cp = buff.timer._points[1], buff.count._points[1]
assert(tp[1] == "TOPRIGHT" and tp[3] == "TOPRIGHT" and tp[4] < 0 and tp[5] < 0 and A.W.LastCall(buff.timer, "SetJustifyH")[1] == "RIGHT", "the timer inside the top right corner")
local timer = Model.Timer(K.Store.Module("Auras"))
assert(Model.TimerArea(timer) == 0, "a corner timer frees the lane")
assert(cp[1] == "TOPRIGHT" and cp[5] <= tp[5] - timer.size, "the stack count steps under the timer, clear of it")
write("timer.position", "LEFT"); write("count.position", "LEFT")
tp, cp = buff.timer._points[1], buff.count._points[1]
assert(tp[1] == "LEFT" and tp[4] > 0 and cp[1] == "LEFT" and cp[5] - tp[5] >= timer.size, "on a side midpoint the count steps above the timer")
write("count.position", "BOTTOM")
cp = buff.count._points[1]
assert(cp[1] == "BOTTOM" and cp[4] == 0 and cp[5] > 0 and A.W.LastCall(buff.count, "SetJustifyH")[1] == "CENTER", "the count on the bottom edge")

-- Type icons on edge midpoints: a count that shares the type icon's anchor sits beside it, a timer in the lane over it.
write("debuffs.typeIcon", "BOTTOM"); write("timer.position", "BOTTOMLEFT")
local icon = debuff.typeIcon
assert(icon._points[1][1] == "BOTTOM" and icon:IsShown() ~= nil, "the type icon on the bottom edge")
assert(debuff.count._points[1][2] == icon and debuff.count._points[1][1] == "BOTTOMRIGHT", "the count beside it")
write("debuffs.typeIcon", "BOTTOMLEFT")
assert(debuff.timer._points[1][2] == icon and debuff.timer._points[1][1] == "BOTTOMLEFT" and debuff.timer._points[1][3] == "TOPLEFT", "a timer in the type icon's corner sits over it")
write("timer.format", "none")
assert(debuff.count._points[1][2] ~= icon and debuff.count._points[1][1] == "BOTTOM", "a hidden timer moves nothing")
write("timer.format", "short"); write("timer.position", "below"); write("count.position", "TOPRIGHT"); write("debuffs.typeIcon", "none")
assert(buff.count._points[1][1] == "TOPRIGHT" and buff.timer._points[1][3] == "BOTTOM" and A.W.LastCall(buff.timer, "SetJustifyH")[1] == "CENTER", "defaults restore today's texts")

-- The live preview: the extra rows show their own categories when on, with the glow; off leaves today's preview.
write("extraDebuffs.glow", true)
local holder = env.CreateFrame("Frame", nil, K.Scale.Root()); holder:SetSize(280, 400)
local preview = ns.Preview.Build(holder)
local function shown(list) local n = 0; for _, e in ipairs(list) do if e.button:IsShown() then n = n + 1 end end; return n end
assert(preview.extraBuffBox:IsShown() and shown(preview.extraBuffs) == 2, "the preview's extra buff row shows the two important samples")
assert(preview.extraDebuffBox:IsShown() and shown(preview.extraDebuffs) == 1 and preview.extraDebuffs[3].glow.holder:IsShown(), "and the crowd control sample, glowing")
write("extraBuffs.enabled", false); write("extraDebuffs.enabled", false)
preview:Refresh()
assert(not preview.extraBuffBox:IsShown() and not preview.extraDebuffBox:IsShown() and shown(preview.buffs) == 7, "off leaves today's preview")

-- Options: the extra sections build lazily and their rows stay disabled until the row is on.
local schema = K.Options.Get("Auras")
local rowsByKey = {}
for _, row in ipairs(schema) do if row.key then rowsByKey[row.key] = row end end
local settings = K.Store.Module("Auras")
assert(rowsByKey["extraBuffs.enabled"] and not rowsByKey["extraBuffs.enchants"] and rowsByKey["extraDebuffs.typeIcon"], "the extra sections hold the row switch and their kind's rows")
assert(rowsByKey["extraBuffs.iconSize"].disableWhen(settings) and rowsByKey["extraBuffs.onlyMine"].disableWhen(settings), "their rows wait for the switch")
assert(not rowsByKey["buffs.glow"].disableWhen and not rowsByKey["buffs.onlyMine"].disableWhen, "the main rows need no switch")

-- verify-608 review probes, each with the option on.
-- A timer sharing the type icon's anchor takes the lane under (or over) it, inside its own tile: a 22-unit "4:05" never
-- paints into the neighbouring tile or on the symbol, at any of the nine anchors.
local G = dofile("Tools/regression/geometry.lua")
local function apart(r, s) return r.right <= s.left or s.right <= r.left or r.top <= s.bottom or s.top <= r.bottom end
debuff.timer:SetSize(22, 11)
for _, pair in ipairs({ { "top", "TOP" }, { "inside", "BOTTOM" }, { "center", "CENTER" }, { "TOPLEFT" }, { "TOPRIGHT" }, { "LEFT" }, { "RIGHT" }, { "BOTTOMLEFT" }, { "BOTTOMRIGHT" } }) do
	write("timer.position", pair[1]); write("debuffs.typeIcon", pair[2] or pair[1])
	local t, i, tile = G.Rect(debuff.timer, debuff.skin), G.Rect(debuff.typeIcon, debuff.skin), debuff.skin:GetWidth()
	assert(t.left >= 0 and t.right <= tile and apart(t, i), pair[1] .. ": the timer stays in its tile, clear of the type icon (" .. t.left .. " to " .. t.right .. " of " .. tile .. ")")
end
-- Without the engine's Icon style the symbol is never drawn, so neither text moves for it.
local styles = env.Enum.CustomAuraButtonDispelTypeTextureStyle
local iconStyle = styles.Icon
styles.Icon = nil
write("timer.position", "LEFT"); write("count.position", "LEFT"); write("debuffs.typeIcon", "LEFT")
assert(debuff.timer._points[1][2] ~= debuff.typeIcon and debuff.count._points[1][2] ~= debuff.typeIcon, "an unbound symbol moves no text")
styles.Icon = iconStyle
write("timer.position", "below"); write("count.position", "TOPRIGHT"); write("debuffs.typeIcon", "none")

-- The glow repaints when its tile's size changes, not on an unrelated setting.
write("debuffs.glow", true)
local painted = calls(debuff.glow.slice[1], "SetPoint")
write("extraDebuffs.refresh", true)
assert(calls(debuff.glow.slice[1], "SetPoint") == painted, "an unrelated setting repaints no glow")
write("debuffs.iconSize", 30)
assert(calls(debuff.glow.slice[1], "SetPoint") > painted, "a new icon size does")
write("debuffs.glow", false); write("debuffs.iconSize", 27.6); write("extraDebuffs.refresh", false)

-- One tracked-layout change reads the Cooldown Manager's tracked buffs once for both buff rows.
write("extraBuffs.enabled", true)
local reads, readSet = 0, ns.Tracked.Set
ns.Tracked.Set = function(...) reads = reads + 1; return readSet(...) end
env.FireEvent("SPELLS_CHANGED")
ns.Tracked.Set = readSet
assert(reads == 1, "both buff rows share one read of the tracked buffs, not " .. reads)
-- SPELLS_CHANGED fires on every spell, talent and form change; with the tracked buffs unchanged no row applies again.
local cost = dofile("Tools/regression/path_budget.lua").Count(env, function() env.FireEvent("SPELLS_CHANGED") end)
dofile("Tools/regression/path_budget.lua").Check(cost, 2000, 0, "an unchanged SPELLS_CHANGED applied the buff rows again; apply only a row whose tracked buffs changed (KstyleUI_Auras/Panel.lua OnTracked)")
-- A Layout fade sets a row's alpha every frame; the engine's host follows with its alpha and shown state only.
local host, wrote = buffs.host, {}
local seen = #host._calls
buffs.holder:SetAlpha(0.5)
for i = seen + 1, #host._calls do
	local method = host._calls[i].method
	if not method:find("^Get") and not method:find("^Is") then wrote[#wrote + 1] = method end
end
assert(#wrote <= 2 and host:GetAlpha() == 0.5, "one alpha step of the buff row wrote " .. table.concat(wrote, ", ") .. " to its host; follow the alpha and shown state only (KstyleUI_Auras/Panel.lua Fade)")
buffs.holder:SetAlpha(1)

-- The preview follows the row's filter and order: Dispellable by you drops the crowd control sample, Reverse order reverses.
write("extraDebuffs.enabled", true); write("extraDebuffs.show", "all")
preview:Refresh()
local samples = preview.extraDebuffs
assert(shown(samples) == 3, "every sample shows")
write("extraDebuffs.dispellable", true); preview:Refresh()
assert(shown(samples) == 2 and not samples[3].button:IsShown(), "Dispellable by you leaves out the crowd control sample, as the live filter does")
write("extraDebuffs.dispellable", false); write("extraDebuffs.reverse", true); preview:Refresh()
assert(samples[3].button._points[1][4] < samples[1].button._points[1][4], "Reverse order reverses the preview")
write("extraDebuffs.reverse", false); write("extraDebuffs.show", "crowdControl")

-- A preset writes the extra rows off, as its preview shows them.
assert(extra.host:IsShown() and K.Setup.Apply({ layout = "Tank", modules = { Auras = true } }))
env.RunTimers()
local stored = K.Store.Module("Auras")
assert(stored.extraBuffs.enabled == false and stored.extraDebuffs.enabled == false and not extra.host:IsShown(), "applying a preset switches the extra rows off")

-- A future aura element under the minimap crest falls back like any other key instead of raising.
K.Store.Profile().Minimap = { enabled = true, frame = "ring" }
assert(Layouts.MinimapCrest() and pcall(Layouts.Aspect, "wide", "medallions", "DPS", "auras.future"), "an aura key the presets do not place raises no error")
assert(#env._errors == 0 and K.ErrorCount() == 0, "the new options raise no errors: " .. tostring(env._errors[1]))
print("auras parity round 2 ok")
