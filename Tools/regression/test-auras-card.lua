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
check(debuffs.columns == 6 and debuffs.spacing == 10 and debuffs.rows == 1, "one row of six debuffs")
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
local expect = Model.Card({ width = 278, height = 102 }, { width = 278, height = 51 }, 20, 8)
check(near(w, expect.width, 0.5) and near(h, expect.height, 0.5), "the buff element is the whole card: " .. tostring(w) .. " x " .. tostring(h) .. " for " .. expect.width .. " x " .. expect.height)
local content = desc.content
check(content and content:GetParent() == desc.host, "the buff rows sit in a content frame on the host")
local cp = content._points[1]
check(cp[1] == "TOPLEFT" and cp[2] == desc.host and near(cp[4], 20, 0.5) and near(-cp[5], expect.contentTop, 0.5), "the content starts under the cap: " .. tostring(cp[4]) .. ", " .. tostring(cp[5]))
local container = A.Container(env, "HELPFUL")
local point, rel = container:GetPoint(1)
check(rel == content, "the container hangs from the content frame, not the host, so the card's padding and cap stay clear: " .. tostring(point))
local ddesc = Panel.Group("debuffs")
check(ddesc.docked == true, "the debuff group knows it is docked")
check(not ddesc.holder:IsShown(), "the docked holder, which Layout owns, is hidden")
local dock = ddesc.dock
check(dock and dock:GetParent() == desc.holder, "a dock frame sits on the buff card's holder")
local dp = dock._points[1]
check(dp[1] == "TOPLEFT" and dp[2] == desc.holder and near(dp[4], 20, 0.5) and near(-dp[5], expect.debuffTop, 0.5), "the dock sits inside the card under the hairline: " .. tostring(dp[4]) .. ", " .. tostring(dp[5]))
local dw, dh = dock:GetSize()
check(near(dw, 278, 0.5) and near(dh, 51, 0.5), "the dock is the debuff row's own size")
local hostPoint = ddesc.host._points[1]
check(hostPoint[2] == dock, "the debuff host follows the dock")
check(ddesc.host:IsShown(), "and shows while the buff card shows")
check(desc.card.rule and desc.card.rule:IsShown(), "a hairline parts the buffs from the debuffs")
local rp = desc.card.rule._points[1]
check(rp[1] == "TOPLEFT" and near(-rp[5], expect.contentTop + 102 + 8, 0.5), "the hairline sits one gap under the buff rows")
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

check(#env._errors == 0, tostring(env._errors[1]))
print("auras card ok")
