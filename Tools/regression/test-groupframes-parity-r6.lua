-- test-groupframes-parity-r6.lua: EllesmereUI parity round 6 on party frames: v0.2.8 profiles keep every new default; the shield edge, role icons under the highlights, indicator squares and bars and party frames that follow the raid's settings apply when on, follow secrecy, reach the preview and switch back. The raid checks are in test-groupframes-parity-r6-raid.lua.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local MODULE = H.MODULE
local write, frame, noErrors, boot, near = H.write, H.frame, H.noErrors, H.boot, H.near

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
end

local function tint(region, i)
	return region._state.ColorTexture[i]
end

local function preview(env, K)
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 520)
	return K.Options.Preview(MODULE)(parent)
end

local function shown(K, key)
	local row = K.Options.Row(MODULE, key)
	return row.showWhen == nil or row.showWhen(K.Store.Module(MODULE)) == true
end

local env, K, ns = boot({ saved = saved({ party = { width = 259 }, indicator1 = { category = "EXTERNAL", position = "CENTER" }, auto = { size = true } }) })

-- A v0.2.8-shaped profile keeps every new default and builds nothing new.
do
	local get = ns.Settings.Get
	assert(get("prediction.edge") == false and get("icons.roleBehind") == false and get("tanks.excludeSelf") == false, "the new switches start off")
	assert(get("auto.customLeast") == 0 and get("auto.customWidth") == 0, "no own raid size")
	for _, section in ipairs({ "text", "auras", "heals", "icons", "power" }) do assert(get("follow." .. section) == false, "party frames keep their own " .. section) end
	for i = 1, ns.Settings.INDICATOR_SLOTS do
		assert(get("indicator" .. i .. ".style") == "ICON" and get("indicator" .. i .. ".thick") == 4 and get("indicator" .. i .. ".reverse") == false and get("indicator" .. i .. ".over") == false, "indicators stay icons")
	end
	local f = frame(ns, "party1")
	assert(f.shieldEdge == nil, "no shield edge is made")
	assert(select(1, f.role:GetDrawLayer()) == "OVERLAY", "role icons keep their layer")
	local p = ns.Auras.Parts(f.indicators._slots.indicator1.frame)
	assert(p.square == nil and p.bar == nil and p.look == nil, "no square or bar is made")
	assert(ns.Settings.current.party.nameSize == 13 and ns.Settings.current.party.auraCount == 6, "party frames keep their own sizes")
	noErrors(env, K)
end

-- The shield edge rides the shield's fill at its inner end, upright on a vertical bar; it needs Absorbs on and off hides it.
do
	local f = frame(ns, "party1")
	write(env, K, "prediction.edge", true)
	local edge, fill = f.shieldEdge, f.absorbs:GetStatusBarTexture()
	assert(edge and edge:IsShown() and edge:GetParent() == f.absorbs and edge:DoesClipChildren(), "a clip frame on the shield")
	local p1, rel1 = edge:GetPoint(1)
	assert(rel1 == fill, "it covers the shield's fill, so an empty shield shows no edge: " .. tostring(p1))
	local line = edge.line
	assert(near(line:GetWidth(), K.Widgets.Border(f) * 2), "two lines wide")
	local a, b = line:GetPoint(1), line:GetPoint(2)
	assert(a == "BOTTOMLEFT" and b == "TOPLEFT", "at the shield's inner end: " .. tostring(a) .. " " .. tostring(b))
	write(env, K, "health.orientation", "VERTICAL")
	a, b = line:GetPoint(1), line:GetPoint(2)
	assert(a == "BOTTOMLEFT" and b == "BOTTOMRIGHT" and near(line:GetHeight(), K.Widgets.Border(f) * 2), "across the foot of an upward shield")
	write(env, K, "health.orientation", "HORIZONTAL")
	assert(shown(K, "prediction.edge"), "its row shows under Absorbs")
	write(env, K, "prediction.absorbs", false)
	assert(not edge:IsShown() and not shown(K, "prediction.edge"), "Absorbs off hides it and its row")
	write(env, K, "prediction.absorbs", true)
	assert(edge:IsShown(), "and returns with Absorbs")
	local pv = preview(env, K)
	local sample = pv.partyFrames[1]
	assert(sample.shieldEdge and sample.shieldEdge:IsShown(), "the preview's shielded tank shows it")
	write(env, K, "prediction.edge", false)
	pv:Refresh()
	assert(not edge:IsShown() and not sample.shieldEdge:IsShown(), "off hides it, in the preview too")
	noErrors(env, K)
end

-- Role icons, pips and letters move under the highlights and back.
do
	local f = frame(ns, "party1")
	write(env, K, "icons.roleText", true)
	write(env, K, "icons.roleBehind", true)
	local layer, sub = f.role:GetDrawLayer()
	assert(layer == "ARTWORK" and sub == 5, "the role icon sits under the hover line and names: " .. tostring(layer))
	assert(select(1, f.pipEdge:GetDrawLayer()) == "ARTWORK" and select(2, f.pipFill:GetDrawLayer()) == 6, "pips too")
	assert(select(1, f.roleLetter:GetDrawLayer()) == "ARTWORK", "and the letter")
	assert(f.target:GetParent() == f.text, "the target ring is a child frame above them")
	local pv = preview(env, K)
	assert(select(1, pv.partyFrames[1].role:GetDrawLayer()) == "ARTWORK", "the preview follows")
	write(env, K, "icons.roleBehind", false)
	layer, sub = f.role:GetDrawLayer()
	assert(layer == "OVERLAY" and sub == 0 and select(2, f.pipFill:GetDrawLayer()) == 1, "off restores the layers")
	assert(select(1, f.roleLetter:GetDrawLayer()) == "OVERLAY" and select(2, f.roleLetter:GetDrawLayer()) == 0, "and the letter's")
	write(env, K, "icons.roleText", false)
	write(env, K, "icons.roleBehind", true)
	write(env, K, "icons.roleText", true)
	assert(select(1, f.roleLetter:GetDrawLayer()) == "ARTWORK", "a letter made later takes the layer")
	write(env, K, "icons.roleBehind", false)
	write(env, K, "icons.roleText", false)
	noErrors(env, K)
end

-- Indicator looks: a square in one colour, a bar on the health bar's edge that the engine drains, under the icons, stepped in past the shield lines, reversed or over the icons, a square without the engine's bar; secrecy waits; icon restores.
do
	local f = frame(ns, "party1")
	local button = f.indicators._slots.indicator1.frame
	local p = ns.Auras.Parts(button)
	write(env, K, "indicator1.style", "SQUARE")
	write(env, K, "indicator1.color", { r = 1, g = 0, b = 0 })
	assert(p.square:IsShown() and tint(p.square, 1) == 1 and tint(p.square, 2) == 0, "a red square over the icon")
	assert(p.skin:GetAlpha() == 1, "inside the kit's icon frame")
	write(env, K, "indicator1.style", "BAR")
	local health = f.parts.health
	assert(p.bar:IsShown() and not p.square:IsShown() and p.skin:GetAlpha() == 0, "a bar replaces the tile")
	assert(button._aura.durationBar == p.bar and button._aura.durationBarOptions.direction == env.Enum.StatusBarTimerDirection.RemainingTime, "the engine drains it with the time left")
	assert(near(button:GetWidth(), K.Widgets.Snap(f, health.width)) and near(button:GetHeight(), K.Widgets.Snap(f, 4)), "the health bar's width, four units thick")
	local _, _, _, _, y = button:GetPoint(1)
	assert(near(y, -K.Widgets.Snap(f, health.top + (health.height - 4) / 2)), "across the middle for a centred place")
	assert(button:GetFrameLevel() == f:GetFrameLevel() + ns.Auras.CONTAINER_LEVEL, "under the debuff and heal icons, over the health bar")
	local line = K.Widgets.Border(f) * ns.Settings.current.prediction.shieldLines
	write(env, K, "indicator1.position", "BOTTOMRIGHT")
	_, _, _, _, y = button:GetPoint(1)
	assert(near(y, -K.Widgets.Snap(f, health.top + health.height - line - 4)), "on the bottom edge, stepped in past the shield line there")
	write(env, K, "prediction.shield", false)
	_, _, _, _, y = button:GetPoint(1)
	assert(near(y, -K.Widgets.Snap(f, health.top + health.height - 4)), "on the edge itself without the shield line")
	write(env, K, "prediction.healAbsorbLine", true)
	write(env, K, "indicator1.position", "TOP")
	_, _, _, _, y = button:GetPoint(1)
	assert(near(y, -K.Widgets.Snap(f, health.top + line)), "past the heal absorb line across from the shield line")
	write(env, K, "prediction.healAbsorbLine", false)
	write(env, K, "prediction.shield", true)
	write(env, K, "indicator1.position", "BOTTOMRIGHT")
	assert(select(1, p.bar:GetStatusBarColor()) == 1, "in its colour")
	write(env, K, "indicator1.position", "LEFT")
	assert(near(button:GetWidth(), K.Widgets.Snap(f, 4)) and near(button:GetHeight(), K.Widgets.Snap(f, health.height)) and p.bar:GetOrientation() == "VERTICAL", "upright on the left edge")
	write(env, K, "indicator1.thick", 20)
	assert(near(button:GetWidth(), K.Widgets.Snap(f, 20)), "as thick as asked")
	write(env, K, "indicator1.position", "TOP")
	assert(near(button:GetHeight(), K.Widgets.Snap(f, health.height)), "never thicker than the health bar")
	write(env, K, "indicator1.reverse", true)
	assert(p.bar:GetReverseFill() == true, "reverse fill")
	local level = button:GetFrameLevel()
	write(env, K, "indicator1.over", true)
	assert(button:GetFrameLevel() > level and button:GetFrameLevel() > f.auras:GetFrameLevel() + 1, "over the debuff icons, with the other indicators")
	write(env, K, "indicator1.over", false)
	assert(button:GetFrameLevel() == level, "off puts it back under them")
	local setBar = button.SetDurationBar
	button.SetDurationBar = nil
	write(env, K, "indicator1.reverse", false)
	assert(p.square:IsShown() and not p.bar:IsShown() and p.skin:GetAlpha() == 1, "without the engine's duration bar a bar stays a square")
	button.SetDurationBar = setBar
	write(env, K, "indicator1.reverse", true)
	assert(p.bar:IsShown() and not p.square:IsShown(), "and becomes a bar again with it")
	assert(not ns.Slots.Misfit("party", 1), "a bar takes no icon spot")
	local pv = preview(env, K)
	local sample = pv.partyFrames[1].sampleSlots[1]
	assert(sample.bar and sample.bar:IsShown() and sample.tile.skin:GetAlpha() == 0, "the preview shows the bar")
	local secret = env.C_Secrets.ShouldAurasBeSecret
	env.C_Secrets.ShouldAurasBeSecret = function() return true end
	K.Options.Write(MODULE, "indicator1.style", "ICON")
	assert(p.bar:IsShown() and button._aura.durationBar == p.bar, "a change while auras are secret waits")
	env.C_Secrets.ShouldAurasBeSecret = secret
	env.RunTimers()
	assert(not p.bar:IsShown() and button._aura.durationBar == nil and p.skin:GetAlpha() == 1 and not p.square:IsShown(), "icon restores the tile once auras are readable")
	write(env, K, "indicator1.style", "SQUARE")
	pv:Refresh()
	assert(tint(sample.tile.icon, 1) == 1 and not sample.bar:IsShown(), "the preview's square")
	for key, value in pairs({ style = "ICON", position = "CENTER", thick = 4, reverse = false, over = false }) do write(env, K, "indicator1." .. key, value) end
	pv:Refresh()
	assert(sample.tile.icon:GetTexture() ~= nil and sample.tile.skin:GetAlpha() == 1, "the preview's icon returns")
	noErrors(env, K)
end

-- Party frames follow the raid's text, debuffs, heal icons, status icon size and power bar, hide their own rows, and switch back.
do
	local f = frame(ns, "party1")
	local current = ns.Settings.current
	write(env, K, "raid.nameSize", 15)
	write(env, K, "raid.auraCount", 2)
	write(env, K, "raid.buffCount", 1)
	write(env, K, "raid.iconSize", 12)
	write(env, K, "raid.powerHeight", 5)
	for _, section in ipairs({ "text", "auras", "heals", "icons", "power" }) do write(env, K, "follow." .. section, true) end
	assert(current.party.nameSize == 15 and current.party.auraCount == 2 and current.party.buffCount == 1 and current.party.iconSize == 12 and current.party.powerHeight == 5, "the raid's values")
	assert(current.party.width == 259 and current.party.height == 39, "sizes stay the party's own")
	assert(select(2, f.name:GetFont()) <= 15 and f.parts.power and near(f.parts.power.height, 5), "the frames follow")
	assert(not shown(K, "party.nameSize") and not shown(K, "party.auraCount") and not shown(K, "party.powerHeight") and shown(K, "party.width"), "the party's own rows hide")
	local pv = preview(env, K)
	assert(near(pv.partyFrames[1].parts.power.height, 5), "the preview follows")
	write(env, K, "raid.nameSize", 16)
	assert(current.party.nameSize == 16, "a raid change reaches the party")
	for _, section in ipairs({ "text", "auras", "heals", "icons", "power" }) do write(env, K, "follow." .. section, false) end
	assert(current.party.nameSize == 13 and current.party.auraCount == 6 and current.party.buffCount == 3 and current.party.iconSize == 14 and current.party.powerHeight == 3, "off restores the party's own")
	assert(shown(K, "party.nameSize"), "and their rows")
	for key, value in pairs({ nameSize = 12, auraCount = 3, buffCount = 3, iconSize = 10, powerHeight = 2 }) do write(env, K, "raid." .. key, value) end
	noErrors(env, K)
end

print("groupframes parity round 6 ok: the shield edge, role icons under the highlights, indicator squares and bars and party frames that follow the raid")
