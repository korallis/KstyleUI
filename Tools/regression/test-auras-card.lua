-- test-auras-card.lua: the Blessings card: one Lumen card on the buff element with a section cap, the buff rows under it, and the debuff row docked in the same card under a hairline, or set free as its own element.
local A = dofile("Tools/regression/auras_env.lua")

local function check(cond, message)
	if not cond then
		error(message, 2)
	end
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < (eps or 1e-6)
end

local function registered(env, key)
	for _, entry in ipairs(env._layout) do
		if entry.key == key then
			return entry
		end
	end
end

local env, K, ns = A.New({ layout = true })
K.Modules.Enable("Auras")
env.RunTimers()
local Model, Panel = ns.Model, ns.Panel
local Widgets = K.Widgets

-- The card maths, pure: the card wraps the widest row inside the rail padding, and stacks cap, buff rows, a
-- hairline and the debuff row.
check(Model.CARD_PAD == 20, "the card pads its content by the Lumen rail padding, 20")
local card = Model.Card({ width = 278, height = 102 }, { width = 278, height = 51 }, 20, 8)
check(near(card.width, 318), "the card is the row plus the padding each side: 318 on the default row, got " .. tostring(card.width))
check(near(card.contentTop, 20 + Widgets.SECTION_CAP_HEIGHT + 8), "the buff rows start under the padding, the cap and a gap")
check(near(card.debuffTop, card.contentTop + 102 + 8 + 1 + 8), "the debuff row starts under the buff rows, a gap, the hairline and a gap")
check(near(card.height, card.debuffTop + 51 + 20), "and the card ends one padding under the debuff row: " .. tostring(card.height))
local alone = Model.Card({ width = 278, height = 102 }, nil, 20, 8)
check(near(alone.height, 20 + Widgets.SECTION_CAP_HEIGHT + 8 + 102 + 20) and alone.debuffTop == nil, "without the debuff row the card ends under the buff rows")
local wide = Model.Card({ width = 100, height = 40 }, { width = 200, height = 40 }, 20, 8)
check(near(wide.width, 240), "the wider row sets the width")

-- Defaults: six icons a row, so the default card is the 318 rail width.
local buffs = Model.Group(K.Store.Module("Auras"), "buffs")
check(buffs.columns == 6 and buffs.spacing == 10, "six buffs a row, 10 apart: 6 x 38 + 5 x 10 = 278 inside the 318 card")
local debuffs = Model.Group(K.Store.Module("Auras"), "debuffs")
check(debuffs.columns == 6 and debuffs.spacing == 10 and debuffs.rows == 2, "two rows of six debuffs, so twelve stay visible")
check(K.Store.Module("Auras").card == nil or Model.Docked(K.Store.Module("Auras")) == true, "the debuff row docks in the card by default")

-- The built card: chrome and cap on the buff host, sized to the card, with the debuff holder docked under it.
local b = registered(env, "auras.buffs")
check(b, "the buff element registers with Layout")
check(registered(env, "auras.debuffs") ~= nil, "the debuff row keeps its Layout element, so a player can set it free")
check(env._live["auras.debuffs"] == false, "but a docked row is not live: no mover plate for it")
local desc = Panel.Group("buffs")
check(desc and desc.card and desc.card.chrome and desc.card.cap, "the buff group carries the card: a chrome and a section cap")
check(desc.card.cap.title:GetText() == "BLESSINGS", "the cap reads Blessings")
local w, h = b.frame:GetSize()
local expect = Model.Card({ width = 278, height = 102 }, { width = 278, height = 102 }, 20, 8)
check(near(w, expect.width, 0.5) and near(h, expect.height, 0.5), "the buff element is the whole card: " .. tostring(w) .. " x " .. tostring(h) .. " for " .. expect.width .. " x " .. expect.height)
local content = desc.content
check(content and content:GetParent() == desc.host, "the buff rows sit in a content frame on the host")
local cp = content._points[1]
check(cp[1] == "TOPLEFT" and cp[2] == desc.holder and near(cp[4], 20, 0.5) and near(-cp[5], expect.contentTop, 0.5), "the content starts under the cap, hung from the Layout holder (the host's bottom follows the content, so the content cannot hang from the host): " .. tostring(cp[4]) .. ", " .. tostring(cp[5]))
local container = A.Container(env, "HELPFUL")
local point, rel = container:GetPoint(1)
check(rel == content, "the container hangs from the content frame, not the host, so the card's padding and cap stay clear: " .. tostring(point))
local ddesc = Panel.Group("debuffs")
check(ddesc.docked == true, "the debuff group knows it is docked")
check(not ddesc.holder:IsShown(), "the docked holder, which Layout owns, is hidden")
local dock = ddesc.dock
check(dock and dock:GetParent() == desc.holder, "a dock frame sits on the buff card's holder")
local dp = dock._points[1]
check(dp[1] == "TOPLEFT" and dp[2] == desc.card.fit and near(dp[4], 0, 0.5) and near(-dp[5], expect.debuffTop - expect.contentTop - 102, 0.5), "the dock hangs under the buff container by a gap, the hairline and a gap: " .. tostring(dp[4]) .. ", " .. tostring(dp[5]))
local dw, dh = dock:GetSize()
check(near(dw, 278, 0.5) and near(dh, 102, 0.5), "the dock is the debuff rows' own size")
local hostPoint = ddesc.host._points[1]
check(hostPoint[2] == dock, "the debuff host follows the dock")
check(ddesc.host:IsShown(), "and shows while the buff card shows")
check(desc.card.rule and desc.card.rule:IsShown(), "a hairline parts the buffs from the debuffs")
local rp = desc.card.rule._points[1]
check(rp[1] == "TOPLEFT" and rp[2] == desc.card.fit and near(-rp[5], 8, 0.5), "the hairline hangs one gap under the buff container")
check(desc.card.chrome.fill[5]:IsShown(), "the card is a frost card, glass under the rows")

-- Setting the debuff row free: it becomes its own element again, bare, and the card shortens.
K.Options.Write("Auras", "card.docked", false)
env.RunTimers()
check(env._live["auras.debuffs"] == true, "a free debuff row is live in Layout Mode")
check(ddesc.docked == false, "and knows it is free")
check(ddesc.holder:IsShown(), "its holder shows again")
local freePoint = ddesc.host._points[1]
check(freePoint[2] == ddesc.holder, "and the host follows the holder")
local _, freeHeight = b.frame:GetSize()
check(near(freeHeight, alone.height, 0.5), "the card ends under the buff rows: " .. tostring(freeHeight))
check(not desc.card.rule:IsShown(), "no hairline without a debuff row")
K.Options.Write("Auras", "card.docked", true)
env.RunTimers()
check(env._live["auras.debuffs"] == false and ddesc.docked == true and not ddesc.holder:IsShown(), "docking again hides the debuff holder and docks the row")
local _, backHeight = b.frame:GetSize()
check(near(backHeight, expect.height, 0.5), "and the card grows back")

-- The card hugs its content. The engine sizes each container to the rows it holds (a secret size, written
-- from secure code), so the glass follows the containers by anchors alone: the hairline and the debuff row
-- hang from the buff container's bottom, and the card's bottom from the debuff container's. A frame anchored
-- to a container needs Blizzard's DisableUntrustedLayoutScriptsTemplate, else the engine refuses the anchor.
local Geometry = dofile("Tools/regression/geometry.lua")
local root = K.Scale.Root()
local function rect(object)
	local r, why = Geometry.Rect(object, root)
	check(r, tostring(why))
	return r
end
local hostile = A.Container(env, "HARMFUL")
for _, frame in ipairs({ desc.host, ddesc.host, dock, desc.card.fit, desc.card.tail, desc.card.edge }) do
	check(frame._template == "DisableUntrustedLayoutScriptsTemplate", "a frame the card anchors to a container carries DisableUntrustedLayoutScriptsTemplate")
end
container:SetSize(278, 51)
hostile:SetSize(278, 51)
local one = rect(desc.host)
check(near(rect(container).top, one.top - expect.contentTop, 0.5), "the buff rows start under the cap")
check(near(rect(desc.card.rule).top, rect(container).bottom - 8, 0.5), "the hairline hangs one gap under the buff container")
check(near(rect(dock).top, rect(container).bottom - 8 - 1 - 8, 0.5), "the debuff row hangs under the hairline")
check(near(one.bottom, rect(hostile).bottom - 20, 0.5), "the card ends one padding under the debuff container")
check(near(one.top - one.bottom, expect.height - 102, 0.5), "one row of buffs and one of debuffs where two of each are reserved: the card is two rows shorter than its footprint: " .. tostring(one.top - one.bottom))
container:SetSize(278, 102)
hostile:SetSize(278, 102)
local two = rect(desc.host)
check(near(two.top - two.bottom, expect.height, 0.5), "a second row of each grows the card by a row each, with no relayout, to the reserved footprint: " .. tostring(two.top - two.bottom))
check(near(rect(dock).top, rect(container).bottom - 17, 0.5), "and the debuff row moves down with it")
hostile:SetSize(0, 0)
local none = rect(desc.host)
check(near(none.bottom, rect(container).bottom - 17 - 20, 0.5), "with no debuffs the card ends a hairline's band under the buffs")
local hw, hh = desc.holder:GetSize()
check(near(hw, expect.width, 0.5) and near(hh, expect.height, 0.5), "the Layout holder keeps the reserved footprint, so the mover plate stays put")
check(near(one.left, rect(desc.holder).left, 0.5) and near(one.right, rect(desc.holder).right, 0.5), "the card keeps the rail width")

-- The card is as tall as the rows it holds, and gone when it holds none. The engine's sizes are secret, so
-- the card asks the game whether the player has any buff or debuff (C_UnitAuras.GetAuraSlots, readable while
-- auras are not secret) and refits on UNIT_AURA: with no debuffs the hairline and its gaps go, so the card
-- ends one padding under the buffs; with nothing at all the card hides, leaving the Layout element in place.
-- In combat, when the answer is secret, the card shows (so a buff gained in combat is never hidden) and keeps
-- the band it last knew: a debuff gained then lands under the buffs, and the hairline returns after combat.
local slots = { HELPFUL = { 1, 2, 3 }, HARMFUL = {} }
env.C_UnitAuras = {
	GetAuraSlots = function(unit, filter, maxSlots)
		check(unit == "player", "the card counts the player's auras")
		local list = slots[filter] or {}
		local out, n = {}, math.min(#list, maxSlots or #list)
		for i = 1, n do
			out[i] = list[i]
		end
		return nil, unpack(out)
	end,
}
hostile:SetSize(0, 0)
container:SetSize(278, 51)
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
local noDebuffs = rect(desc.host)
check(desc.host:IsShown(), "buffs alone keep the card")
check(not desc.card.rule:IsShown(), "no debuffs, no hairline")
check(near(noDebuffs.bottom, rect(container).bottom - 20, 0.5), "with no debuffs the card ends one padding under the buffs, no dead band: " .. tostring(noDebuffs.bottom - (rect(container).bottom - 20)))
slots.HARMFUL = { 7 }
hostile:SetSize(278, 51)
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
check(desc.card.rule:IsShown(), "a debuff brings the hairline back")
check(near(rect(desc.host).bottom, rect(hostile).bottom - 20, 0.5), "and the card ends under the debuff row again")
slots.HELPFUL, slots.HARMFUL = {}, {}
container:SetSize(0, 0)
hostile:SetSize(0, 0)
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
check(not desc.host:IsShown(), "with no auras at all the card hides")
check(desc.holder:IsShown() and near(select(2, desc.holder:GetSize()), expect.height, 0.5), "the Layout element stays, at its footprint, for the mover plate")
slots.HELPFUL = { 1 }
container:SetSize(38, 51)
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
check(desc.host:IsShown(), "the first buff brings the card back")
-- Secret auras: the answer is unknown, so the card shows with its band, whatever it last knew.
slots.HELPFUL, slots.HARMFUL = {}, {}
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
check(not desc.host:IsShown(), "empty again")
env._aurasSecret = true
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
check(desc.host:IsShown(), "while auras are secret the card shows: a buff gained in combat is never hidden")
check(not desc.card.rule:IsShown(), "and keeps the band it last knew: no debuffs, no hairline")
env._aurasSecret = false
env.FireEvent("PLAYER_REGEN_ENABLED")
env.RunTimers()
check(not desc.host:IsShown(), "out of combat the card reads the auras again and hides when empty")
-- PLAYER_REGEN_DISABLED fires before the lockdown and before auras turn secret, so the card shows on that event
-- itself rather than trust an answer about to go stale.
env.SetCombat(true)
env.RunTimers()
check(desc.host:IsShown(), "entering combat shows the card at once")
env.SetCombat(false)
env.RunTimers()
check(not desc.host:IsShown(), "and leaving it reads the auras again")
slots.HARMFUL = { 3 }
env.FireEvent("UNIT_AURA", "player")
env.RunTimers()
check(desc.host:IsShown() and not desc.card.rule:IsShown(), "a debuff alone shows the card, with no hairline over empty buff rows")
check(near(rect(desc.host).bottom, rect(hostile).bottom - 20, 0.5), "and the card ends one padding under the debuff rows")
env.SetCombat(true)
env.RunTimers()
check(not desc.card.rule:IsShown(), "and combat keeps that shape too")
env.SetCombat(false)
env.RunTimers()

check(#env._errors == 0, tostring(env._errors[1]))
print("auras card ok")
