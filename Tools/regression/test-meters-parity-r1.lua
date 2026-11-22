-- test-meters-parity-r1.lua: card opacity, header, text sizes, player marker, reset and show/hide keys, combat timer and spell history: defaults keep today's card, each option works switched on, follows its events and restores when off.
local M = dofile("Tools/regression/meters_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function Party(e)
	e._group = { raid = false, size = 5 }
	e._units.player.guid = "Player-3"
	e._resets = 0
end
local env, K, ns = M.New({ saved = { version = 42, profiles = { Default = { Meters = { enabled = true, followRole = false, damage = { shown = true, mode = "window" } } } }, characters = {} }, game = Party })
env.C_DamageMeter.ResetAllCombatSessions = function() env._resets = env._resets + 1 end
local sources = {}
for i = 1, 5 do
	sources[i] = { name = "Player " .. i, classFilename = "WARRIOR", totalAmount = 6000 - i * 1000, amountPerSecond = 600 - i * 100,
		sourceGUID = "Player-" .. i, sourceDisplayType = 1, isLocalPlayer = i == 3 }
end
env._session = { combatSources = sources, maxAmount = 5000, totalAmount = 15000, durationSeconds = 10 }
M.Enable(env, K); env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers()
local list, root = ns.Damage.list, K.Scale.Root()
local function Rect(region) return assert(Geometry.Rect(region, root)) end
local function Errors(label) assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": " .. tostring(env._errors[1])) end

-- Defaults: a v0.2.8 profile keeps today's card.
for key, value in pairs({ ["damage.panelAlpha"] = 1, ["damage.capAlpha"] = 1, ["damage.headerHeight"] = 0, ["damage.titleX"] = 0, ["damage.titleY"] = 0,
	["damage.resetButton"] = false, ["damage.nameScale"] = 1, ["damage.valueScale"] = 1, ["damage.playerMarker"] = false, ["timer.shown"] = false,
	["history.icons"] = false, ["history.bars"] = false }) do
	assert(ns.Get(key) == value, key .. " keeps its v0.2.8 default")
end
assert(not list.panel.chrome.ownFill and not list.resetButton and M.Calls(list.cap.frame, "SetAlpha") == 0, "the default card keeps its fill, title and buttons")
assert(not ns.Timer.holder and not ns.History.holder and not ns.History.list, "the timer and spell history build nothing until switched on")
local top, capRect, rowRect = list:Top(), Rect(list.cap.frame), Rect(list.rows[1].frame)

-- Background and title opacity.
M.Write(env, K, "damage.panelAlpha", 0.5)
local fill = list.panel.chrome.fillColor
assert(list.panel.chrome.ownFill and math.abs(fill[4] - K.Widgets.Setting("panelOpacity") * 0.5) < 1e-6, "background opacity halves the card's fill")
M.Write(env, K, "damage.panelAlpha", 1)
assert(not list.panel.chrome.ownFill, "full background opacity gives the card its shared fill back")
M.Write(env, K, "damage.capAlpha", 0.4)
assert(list.cap.frame:GetAlpha() == 0.4, "title opacity fades the title")
M.Write(env, K, "damage.capAlpha", 1)
assert(list.cap.frame:GetAlpha() == 1, "title opacity restores")

-- Header height and title offsets move the rows with the title, so nothing overlaps.
M.Write(env, K, "damage.headerHeight", 8)
assert(math.abs(list:Top() - top - 8) < 1e-6 and Rect(list.rows[1].frame).top < rowRect.top - 7, "header height moves the rows down")
M.Write(env, K, "damage.headerHeight", 0)
M.Write(env, K, "damage.titleX", 10); M.Write(env, K, "damage.titleY", 4)
local moved, first = Rect(list.cap.frame), Rect(list.rows[1].frame)
assert(math.abs(moved.left - capRect.left - 10) < 1 and math.abs(capRect.top - moved.top - 4) < 1, "title offsets move the title")
assert(math.abs(moved.right - capRect.right) < 1 and first.top <= moved.bottom, "the title stays inside the card and clear of the rows")
M.Write(env, K, "damage.titleX", 0); M.Write(env, K, "damage.titleY", 0)
assert(list:Top() == top and math.abs(Rect(list.rows[1].frame).top - rowRect.top) < 1e-6, "header settings restore")

-- Name and number sizes grow the row instead of overlapping the bar.
local row = list.rows[1]
local nameSize, valueSize, minRow = select(2, row.name:GetFont()), select(2, row.value:GetFont()), list:MinRow()
M.Write(env, K, "damage.nameScale", 1.5); M.Write(env, K, "damage.valueScale", 2)
assert(math.abs(select(2, row.name:GetFont()) - nameSize * 1.5) < 0.01 and math.abs(select(2, row.value:GetFont()) - valueSize * 2) < 0.01, "text sizes scale the row text")
assert(list:MinRow() > minRow, "larger text makes taller rows")
assert(math.abs(select(2, row.percent:GetFont()) - valueSize * 2) < 0.01, "the share follows the number size")
M.Write(env, K, "damage.nameScale", 1); M.Write(env, K, "damage.valueScale", 1)
assert(select(2, row.name:GetFont()) == nameSize and list:MinRow() == minRow, "text sizes restore")

-- Player marker: only your own row, on damage and threat, and never on a spell list.
local function Mine()
	for i = 1, list.count do
		local marker = list.rows[i].marker
		if marker and marker:IsShown() then return i end
	end
end
M.Write(env, K, "damage.playerMarker", true)
env.FireEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED"); env.RunTimers()
assert(Mine() == 3 and M.Last(list.rows[3].name, "SetText")[1] == "Player 3", "the marker shows on your own row only")
local stripe = Rect(list.rows[3].marker)
assert(math.abs(stripe.left - Rect(list.rows[3].bar).left) < 1e-6 and stripe.right - stripe.left < 3, "the marker is a thin stripe at the bar's start")
env._sources["Player-3"] = { combatSpells = { { spellID = 1, totalAmount = 10, amountPerSecond = 1 } }, maxAmount = 10, totalAmount = 10 }
list.rows[3].frame._scripts.OnMouseUp(list.rows[3].frame, "LeftButton"); env.RunTimers()
assert(not Mine(), "a spell list shows no marker")
list.rows[1].frame._scripts.OnMouseUp(list.rows[1].frame, "LeftButton"); env.RunTimers()
assert(Mine() == 3, "the marker comes back with the sources")
M.Write(env, K, "damage.playerMarker", false)
assert(not Mine(), "turning the marker off hides it at once")

-- Reset button: on the title's right end, after combat, and on mouseover only when asked.
M.Write(env, K, "damage.resetButton", true)
local button = assert(list.resetButton)
local b, cap, panel = Rect(button), Rect(list.cap.frame), Rect(list.panel)
assert(button:IsShown() and b.left >= cap.right - 1e-6 and b.right <= panel.right - list.pad + 1e-6, "the reset button sits right of the title, inside the card")
assert(math.abs(b.top - b.bottom - 12) < 1, "the reset button is 12 units by default")
button._scripts.OnClick(button)
assert(env._resets == 1, "the reset button clears every fight")
env.SetCombat(true)
button._scripts.OnClick(button)
assert(env._resets == 1, "a reset in combat waits")
env.SetCombat(false); env.RunTimers()
assert(env._resets == 2, "a waiting reset runs after combat")
M.Write(env, K, "damage.resetSize", 18)
assert(math.abs(Rect(button).top - Rect(button).bottom - 18) < 1, "reset button size")
M.Write(env, K, "damage.resetHover", true)
assert(not button:IsShown(), "a mouseover reset button hides until you point at the meter")
list.panel._mouseOver = true; list.panel._scripts.OnEnter(list.panel)
assert(button:IsShown(), "pointing at the meter shows the reset button")
list.panel._mouseOver = false; list.rows[1].frame._scripts.OnLeave(list.rows[1].frame)
assert(not button:IsShown(), "leaving the meter hides the reset button")
M.Write(env, K, "damage.resetButton", false)
assert(not button:IsShown() and math.abs(Rect(list.cap.frame).right - cap.right - (b.right - b.left) - list.gap) < 1, "turning the button off gives the title its room back")
Errors("card options")

-- Combat timer.
M.Write(env, K, "timer.shown", true)
local timer = ns.Timer
assert(timer.holder:IsShown() and not timer.text:IsShown(), "out of combat the timer waits for a fight")
env.SetTime(200); env.SetCombat(true)
assert(timer.text:IsShown() and M.Last(timer.text, "SetText")[1] == "0:00", "combat starts the timer")
env.SetTime(265.4); env.RunTickers()
assert(M.Last(timer.text, "SetText")[1] == "1:05", "the timer counts the fight")
M.Write(env, K, "timer.decimal", true)
assert(M.Last(timer.text, "SetText")[1] == "1:05.4" and timer.ticker.interval == 0.1, "tenths tick ten times a second")
M.Write(env, K, "timer.align", "LEFT")
assert(M.Last(timer.text, "SetJustifyH")[1] == "LEFT", "alignment")
M.Write(env, K, "timer.color", { r = 1, g = 0, b = 0 })
assert(M.Last(timer.text, "SetTextColor")[1] == 1 and M.Last(timer.text, "SetTextColor")[2] == 0, "timer colour")
local ticker = timer.ticker
env.SetTime(270); env.SetCombat(false)
assert(not timer.text:IsShown() and ticker.cancelled and not timer.ticker, "combat's end stops and hides the timer")
M.Write(env, K, "timer.ooc", true)
assert(timer.text:IsShown() and M.Last(timer.text, "SetText")[1] == "1:10.0", "out of combat it keeps the last fight")
M.Write(env, K, "timer.desat", true)
local r, g, bl = unpack(M.Last(timer.text, "SetTextColor"))
assert(r == g and g == bl and r > 0, "out of combat the time greys")
env.SetCombat(true)
assert(M.Last(timer.text, "SetTextColor")[1] == 1 and M.Last(timer.text, "SetTextColor")[2] == 0, "combat gives the timer its colour back")
env.SetCombat(false)
env.FireEvent("PLAYER_ENTERING_WORLD")
assert(timer.text:IsShown() and not timer.ticker, "a loading screen out of combat keeps the timer stopped")

-- Show or hide meters key.
local toggle = assert(env.KstyleUI_MetersToggle, "the show/hide key's button")
assert(env["BINDING_NAME_CLICK KstyleUI_MetersToggle:LeftButton"] and env["BINDING_NAME_CLICK KstyleUI_MetersReset:LeftButton"], "both keys have a name in Key Bindings")
toggle._scripts.OnClick(toggle); env.RunTimers()
assert(not list.panel:IsShown() and timer.text:IsShown(), "the key hides the meters; the timer stays unless included")
toggle._scripts.OnClick(toggle); env.RunTimers()
assert(list.panel:IsShown(), "the key shows the meters again")
M.Write(env, K, "timer.toggle", true)
toggle._scripts.OnClick(toggle); env.RunTimers()
assert(not list.panel:IsShown() and not timer.text:IsShown(), "an included timer hides with the meters")
toggle._scripts.OnClick(toggle); env.RunTimers()
assert(list.panel:IsShown() and timer.text:IsShown(), "and shows again")
env.KstyleUI_MetersReset._scripts.OnClick(env.KstyleUI_MetersReset)
assert(env._resets == 3, "the reset key clears every fight")
M.Write(env, K, "timer.shown", false)
assert(not timer.holder:IsShown(), "turning the timer off hides it")
Errors("timer")

-- Spell history.
env._spells[11] = { name = "Spell 11", icon = 111 }
env._spells[12] = { name = "Spell 12", icon = 112 }
env._spells[13] = { name = "Spell 13", icon = 113 }
local texture = env.C_Spell.GetSpellTexture
env.C_Spell.GetSpellTexture = function(id) return texture(env.issecretvalue(id) and env.Reveal(id) or id) end
local function Cast(id) env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", id) end
Cast(11)
M.Write(env, K, "history.icons", true)
local history = ns.History
assert(history.holder:IsShown() and not history.icons[1].frame:IsShown(), "a cast before history was on is not kept")
Cast(11); Cast(12); Cast(env.Secret(13))
local icons = history.icons
assert(M.Last(icons[1].texture, "SetTexture")[1] == 113 and M.Last(icons[2].texture, "SetTexture")[1] == 112, "the newest spell leads, secret spells too")
local one, two = Rect(icons[1].frame), Rect(icons[2].frame)
assert(one.left > two.right and math.abs(one.left - two.right - 2) <= 1 and math.abs(one.right - one.left - 28) <= 1, "icons grow left, 28 units apart by 2")
M.Write(env, K, "history.grow", "DOWN"); M.Write(env, K, "history.size", 20); M.Write(env, K, "history.gap", 6)
one, two = Rect(icons[1].frame), Rect(icons[2].frame)
assert(one.bottom > two.top and math.abs(one.bottom - two.top - 6) <= 1 and math.abs(one.top - one.bottom - 20) <= 1, "grow down, size and spacing")
M.Write(env, K, "history.count", 2)
assert(icons[1].frame:IsShown() and icons[2].frame:IsShown() and not icons[3].frame:IsShown(), "most icons")
assert(M.Calls(history.group, "Play") >= 1 and M.Last(history.group, "Play")[1] == true, "a new spell slides in")
local plays = M.Calls(history.group, "Play")
M.Write(env, K, "history.anim", "none"); Cast(11)
assert(M.Calls(history.group, "Play") == plays, "no animation when off")
M.Write(env, K, "history.fade", 5)
env.SetCombat(true); env.SetCombat(false)
env.RunTimers()
assert(not history.strip:IsShown(), "the strip fades after the chosen time out of combat")
Cast(12)
assert(history.strip:IsShown(), "a new spell brings the strip back")
env.SetCombat(true); env.RunTimers()
assert(history.strip:IsShown(), "the fade waits while you fight")
env.SetCombat(false); M.Write(env, K, "history.fade", 0); env.RunTimers()
env.IsInInstance = function() return true, "party" end
M.Write(env, K, "history.hideDungeon", true)
assert(not history.strip:IsShown(), "hide in dungeons")
env.IsInInstance = function() return false, "none" end
env.FireEvent("ZONE_CHANGED_NEW_AREA")
assert(history.strip:IsShown(), "leaving the dungeon shows the strip again")
M.Write(env, K, "history.hideWorld", true)
assert(not history.strip:IsShown(), "hide outside instances")
M.Write(env, K, "history.hideWorld", false)
env.C_DelvesUI = { HasActiveDelve = function() return true end }
M.Write(env, K, "history.hideDelve", true)
assert(not history.strip:IsShown(), "hide in delves")
env.C_DelvesUI = nil
env.FireEvent("PLAYER_ENTERING_WORLD")
assert(history.strip:IsShown(), "leaving the delve shows the strip again")
M.Write(env, K, "history.bars", true)
local bars = history.list
assert(bars.panel:IsShown() and M.Last(bars.rows[1].name, "SetText")[1] == "Spell 12", "bars list the newest spell first")
assert(M.Last(bars.rows[1].icon, "SetTexture")[1] == 112 and bars.count == math.min(bars.capacity, 5), "bars show each spell's icon, up to the card's rows")
M.Write(env, K, "history.barCount", 1)
assert(bars.count == 1, "most bars")
M.Write(env, K, "history.title", false)
assert(not bars.cap.frame:IsShown(), "hide the card's title")
assert(select(1, ns.BarColor("history", "WARRIOR", "friendly")) == select(1, K.Theme.ClassColor("WARRIOR")), "bars take your class colour")
M.Write(env, K, "history.colorSource", "custom"); M.Write(env, K, "history.color", { r = 0, g = 1, b = 0 })
local cr, cg = ns.BarColor("history", "WARRIOR", "friendly")
assert(cr == 0 and cg == 1 and bars.rows[1].g == 1, "custom bar colour")
M.Write(env, K, "history.toggle", true)
toggle._scripts.OnClick(toggle); env.RunTimers()
assert(not bars.panel:IsShown() and not history.strip:IsShown(), "included spell history hides with the meters")
toggle._scripts.OnClick(toggle); env.RunTimers()
assert(bars.panel:IsShown() and history.strip:IsShown(), "and shows again")
M.Write(env, K, "history.icons", false); M.Write(env, K, "history.bars", false)
assert(not history.holder:IsShown() and not bars.holder:IsShown(), "turning spell history off hides both")
Cast(11)
Errors("history")

-- The live preview shows each option.
local parent = env.CreateFrame("Frame", nil, env.UIParent); parent:SetSize(900, 500); parent:SetPoint("CENTER", env.UIParent, "CENTER")
for key, value in pairs({ ["damage.resetButton"] = true, ["damage.resetHover"] = false, ["damage.playerMarker"] = true, ["timer.shown"] = true, ["history.icons"] = true, ["history.bars"] = true }) do M.Write(env, K, key, value) end
local function PRect(region) return assert(Geometry.Rect(region, env.UIParent)) end
local preview = ns.Preview.Build(parent)
assert(preview.damage.resetButton and preview.damage.resetButton:IsShown(), "the preview shows the reset button")
local marked = false
for i = 1, preview.threat.count do marked = marked or (preview.threat.rows[i].marker and preview.threat.rows[i].marker:IsShown()) or false end
assert(marked, "the preview marks your threat row")
assert(preview.timer:IsShown() and preview.strip.icons[1].frame:IsShown() and preview.history.holder:IsShown() and preview.history.count > 0, "the preview shows the timer, the icons and the bars")
local parts = { preview.damage.holder, preview.threat.holder, preview.history.holder, preview.strip.holder, preview.timer }
for i, part in ipairs(parts) do
	for j = i + 1, #parts do
		local h, o = PRect(part), PRect(parts[j])
		assert(h.right <= o.left + 1e-6 or o.right <= h.left + 1e-6 or h.top <= o.bottom + 1e-6 or o.top <= h.bottom + 1e-6, "preview parts never overlap: " .. i .. " and " .. j)
	end
end
Errors("preview")

-- The new elements' default places, and the threat card docked beside the damage card in Both, stay clear of the HUD on every owner screen, style and layout.
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		for _, layout in ipairs({ "DPS", "Tank", "Healer" }) do
			local e, k, n = M.New({ width = screen[1], height = screen[2], followRole = true,
				saved = { version = 42, account = { setupSeen = true }, profiles = { Default = {
					Meters = { timer = { shown = true }, history = { icons = true, bars = true }, damage2 = { shown = true },
						roles = { TANK = "both", HEALER = "both", DAMAGER = "both" }, threat = { group = false } } } } },
				setup = function(x) x._fitScale, x._size = true, "auto" end })
			assert(k.Setup.Apply({ layout = layout, modules = { Meters = true } }))
			e.RunTimers()
			local r0, layouts = k.Scale.Root(), k.Setup.Layouts
			local preset = k.Store.Module("Layout").preset
			local places, enabled = layouts.Positions(preset, style, k.Scale.Aspect()), layouts.Enabled(preset)
			local mine = {}
			for name, holder in pairs({ timer = n.Timer.holder, icons = n.History.holder, bars = n.History.list.holder, second = n.Damage2.holder }) do
				mine[name] = assert(Geometry.Rect(holder, r0))
			end
			local s, t = mine.second, assert(Geometry.Rect(n.Threat.holder, r0))
			assert(n.Threat.list.panel:IsVisible() and (s.right <= t.left or t.right <= s.left or s.top <= t.bottom or t.top <= s.bottom),
				string.format("%dx%d %s %s: the second window overlaps the threat card shown with the damage meter", screen[1], screen[2], style, layout))
			for p, lhs in pairs(mine) do
				for q, second in pairs(mine) do
					assert(p == q or lhs.right <= second.left or second.right <= lhs.left or lhs.top <= second.bottom or second.top <= lhs.bottom, p .. " overlaps " .. q)
				end
			end
			M.Write(e, k, "damage2.shown", false)
			assert(n.Threat.paired, "the threat card docks beside the damage card in Both")
			mine["docked threat"] = assert(Geometry.Rect(n.Threat.holder, r0))
			for _, element in ipairs(layouts.ELEMENTS) do
				local key = element.key
				if enabled[key] ~= false and places[key] and not (style == "orbs" and key == "unitframes.player") then
					local w, h2 = layouts.StyleSize(style, k.Scale.Aspect(), key)
					if not w then w, h2 = layouts.Footprint(preset, key, style, k.Scale.Aspect()) end
					local styled = layouts.Aspect(k.Scale.Aspect(), style, preset, key) or layouts.Style(style, preset, key)
					if styled and styled.width then w, h2 = styled.width, styled.height end
					local left, bottom, right, top2 = layouts.Rect({ width = w, height = h2 }, places[key], r0:GetWidth(), r0:GetHeight())
					for name, rect in pairs(mine) do
						assert(rect.right <= left + 1 or right <= rect.left + 1 or rect.top <= bottom + 1 or top2 <= rect.bottom + 1,
							string.format("%dx%d %s %s: %s overlaps %s; move its default place", screen[1], screen[2], style, layout, name, key))
					end
				end
			end
			for _, guide in ipairs({ true, false }) do
				for _, card in pairs(layouts.Story(preset, r0:GetHeight(), guide, r0:GetWidth()) or {}) do
					if type(card) == "table" and card.anchor and card.width > 0 and card.height > 0 then
						local left, bottom, right, top2 = layouts.Rect(card, card, r0:GetWidth(), r0:GetHeight())
						for name, rect in pairs(mine) do
							assert(rect.right <= left + 1 or right <= rect.left + 1 or rect.top <= bottom + 1 or top2 <= rect.bottom + 1,
								string.format("%dx%d %s %s: %s overlaps the story rail's %s; move its default place", screen[1], screen[2], style, layout, name, card.key))
						end
					end
				end
			end
			assert(#e._errors == 0 and k.ErrorCount() == 0, tostring(e._errors[1]))
		end
	end
end
print("meters parity round 1 ok")
