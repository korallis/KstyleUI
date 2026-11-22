local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W
local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

local function New(style)
	local env, K, ns = U.New({ saved = { version = U.DbVersion(), characters = {}, profiles = { Default = {
		UnitFrames = { enabled = true, target = { auraFilter = "both" } },
	} } } })
	U.SetUnit(env, "target", { name = "Wolf", level = 10, health = 50, healthMax = 100, reaction = 2 })
	env.SetTarget(true)
	return env, K, ns.Frames.Get("target").views[1], ns
end

local function Entry(view, group)
	local button = view.auras.container._groups[group].buttons[1]
	button:SetPoint("TOPLEFT", view.auras.container, "TOPLEFT", 0, group == "buffs" and -50 or 0)
	for _, entry in ipairs(view.auras.buttons) do
		if entry.button == button then
			entry.icon:SetTexture(136118)
			for _, texture in ipairs(button._aura.dispel or {}) do
				texture:SetVertexColor(0.2, 0.6, 1)
				texture:Show()
			end
			return entry
		end
	end
	error("the active group has no dressed tile")
end

local function Below(tint, icon)
	local a, b = tint:GetParent(), icon:GetParent()
	if a:GetFrameLevel() ~= b:GetFrameLevel() then
		return a:GetFrameLevel() < b:GetFrameLevel()
	end
	if a ~= b then
		return false
	end
	local al, as = tint:GetDrawLayer()
	local bl, bs = icon:GetDrawLayer()
	return LAYERS[al] < LAYERS[bl] or al == bl and (as or 0) < (bs or 0)
end

local function Signature(entry)
	local nodes, ids, lines = {}, {}, {}
	local unused = {}
	if not entry.chrome.visible then
		for _, key in ipairs({ "shadow", "fill", "rim", "line" }) do
			for _, region in ipairs(entry.chrome[key] or {}) do
				assert(not region:IsShown(), "unused socket chrome must stay hidden behind the Medallions tile")
				unused[region] = true
			end
		end
	end
	local function Add(node)
		ids[node] = tostring(#nodes + 1)
		nodes[#nodes + 1] = node
		local regions, order = { node:GetRegions() }, {}
		for i, region in ipairs(regions) do order[region] = i end
		table.sort(regions, function(a, b)
			local al, az = a:GetDrawLayer()
			local bl, bz = b:GetDrawLayer()
			al, bl = LAYERS[al] or 0, LAYERS[bl] or 0
			if al ~= bl then return al < bl end
			if (az or 0) ~= (bz or 0) then return (az or 0) < (bz or 0) end
			return order[a] < order[b]
		end)
		for _, region in ipairs(regions) do
			if not unused[region] then
				ids[region] = tostring(#nodes + 1)
				nodes[#nodes + 1] = region
			end
		end
		for _, child in ipairs({ node:GetChildren() }) do
			Add(child)
		end
	end
	Add(entry.skin)
	local function Pack(...)
		local out = {}
		for i = 1, select("#", ...) do
			local value = select(i, ...)
			out[i] = type(value) == "number" and string.format("%.5f", value) or tostring(value)
		end
		return table.concat(out, ",")
	end
	for _, node in ipairs(nodes) do
		local kind = node:GetObjectType()
		local owner = kind == "Texture" or kind == "MaskTexture" or kind == "FontString"
		local frame = owner and node:GetParent() or node
		lines[#lines + 1] = Pack(kind, ids[node:GetParent()] or "button", frame:GetFrameLevel(), node:IsShown(), node:GetAlpha(), node:GetSize())
		if owner then
			lines[#lines + 1] = Pack(node:GetDrawLayer())
		end
		if kind == "Texture" or kind == "MaskTexture" then
			lines[#lines + 1] = Pack(node:GetTexture()) .. ";" .. Pack(node:GetTexCoord()) .. ";" .. Pack(node:GetVertexColor())
			lines[#lines + 1] = Pack(unpack(W.LastCall(node, "SetColorTexture") or {}))
			local gradient = W.LastCall(node, "SetGradient")
			if gradient then
				local a, b = gradient[2], gradient[3]
				lines[#lines + 1] = Pack(gradient[1], a.r, a.g, a.b, a.a, b.r, b.g, b.b, b.a)
			end
		elseif kind == "FontString" then
			lines[#lines + 1] = Pack(node:GetFont()) .. ";" .. Pack(node:GetTextColor())
		end
		for i = 1, node:GetNumPoints() do
			local anchor, relative, point, x, y = node:GetPoint(i)
			lines[#lines + 1] = Pack(anchor, ids[relative] or "button", point, x, y)
		end
	end
	return table.concat(lines, "\n")
end

local controls = {}
local function Control(style)
	if not controls[style] then
		local env, K, view = New(style)
		controls[style] = { env = env, K = K, view = view }
	end
	return controls[style].view
end

for _, pair in ipairs({
	{ "medallions", "frames", combat = "orbs", gateLast = false }, { "medallions", "orbs" }, { "frames", "medallions" },
	{ "orbs", "medallions", combat = "frames", gateLast = true }, { "frames", "orbs", combat = "medallions", gateLast = true }, { "orbs", "frames" },
}) do
	local env, K, view = New(pair[1])
	local before, old = view.auras.container, Entry(view, "debuffs")
	env.RunTimers()
	W.Settle(env)
	local control = Control(pair[2])
	for _, group in ipairs({ "debuffs", "buffs" }) do
		local switched, born = Entry(view, group), Entry(control, group)
		for _, tint in ipairs(switched.button._aura.dispel or {}) do
			local icon = switched.icon
			local overlaps = tint:GetLeft() < icon:GetRight() and icon:GetLeft() < tint:GetRight()
				and tint:GetBottom() < icon:GetTop() and icon:GetBottom() < tint:GetTop()
			assert(not overlaps or Below(tint, icon), pair[1] .. "->" .. pair[2] .. ": the icon must draw above every overlapping dispel tint")
		end
		assert(Signature(switched) == Signature(born), pair[1] .. "->" .. pair[2] .. " " .. group .. ": rebuild tiles with the target style's creation code; their complete region trees must match")
		assert(#(switched.button._aura.dispel or {}) == #(born.button._aura.dispel or {}), "the target style owns the same dispel texture set")
	end
	assert(view.auras.container ~= before and before._enabled == false and not old.skin:IsVisible(), "release old-style tiles and hide their container")
	for _, group in ipairs({ "debuffs", "buffs" }) do
		assert(not before._groups[group].enabled, "disable both old groups so the engine releases their active frames")
	end
	local targetPool = view.auras.container
	env.RunTimers()
	env.RunTimers()
	assert(view.auras.container == targetPool, "reuse only a pool born in the same target style, rather than leaking containers on repeated switches")
	assert(Signature(Entry(view, "debuffs")) == Signature(Entry(control, "debuffs")), "a reused style pool still matches fresh tiles")

	local third, gateLast = pair.combat, pair.gateLast
	if third then
		local label = pair[2] .. "->" .. third .. " in combat, " .. (gateLast and "combat ending before the aura gate opens" or "the aura gate opening before combat ends")
		local function OpenGate()
			env._restricted = false
			env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
			env.RunTimers()
		end
		env.SetCombat(true)
		env._restricted = true
		env.RunTimers()
		assert(K.HudStyle.Current() == pair[2], label .. ": a style picked in combat lockdown is held until combat ends")
		assert(view.auras.container == targetPool and targetPool._enabled ~= false and targetPool:IsShown(), label .. ": combat lockdown keeps the old style's live tiles")
		if not gateLast then
			OpenGate()
			assert(view.auras.container == targetPool, label .. ": an open aura gate does not rebuild tiles for a style still queued behind combat")
		end
		env.SetCombat(false)
		env.RunTimers()
		assert(K.HudStyle.Current() == third, label .. ": the queued style applies when combat ends")
		if gateLast then
			assert(view.auras.container == targetPool and targetPool._enabled ~= false, label .. ": the old tiles stay until aura buttons are readable")
			OpenGate()
		end
		W.Settle(env)
		assert(view.auras.container ~= targetPool and targetPool._enabled == false and not targetPool:IsShown(), label .. ": release the old-style tiles once combat has ended and the aura gate is open")
		for _, group in ipairs({ "debuffs", "buffs" }) do
			assert(Signature(Entry(view, group)) == Signature(Entry(Control(third), group)), label .. " " .. group .. ": tiles rebuilt after combat match tiles born in the target style")
		end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, "aura style switches must stay error-free: " .. table.concat(env._errors, "\n"))
end
for style, control in pairs(controls) do
	assert(#control.env._errors == 0 and control.K.ErrorCount() == 0, "the " .. style .. " control must stay error-free")
end
do
	local env, K, view = New("medallions")
	local old = view.auras.container
	env._restricted = true
	env.RunTimers()
	assert(view.auras.container == old, "release/rebuild waits until the engine's aura buttons are readable")
	env._restricted = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.RunTimers()
	assert(view.auras.container ~= old, "the queued rebuild uses the current style when restriction ends")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "a deferred style rebuild must stay error-free")
end
do
	local env, K, view, ns = New("medallions")
	local focus = ns.Frames.Get("focus").views[1]
	local restyle, nested = ns.Fan.Restyle, false
	ns.Fan.Restyle = function(current)
		if current == view and not nested then
			nested = true
			ns.Auras.Apply(focus)
		end
		return restyle(current)
	end
	env._restricted = true
	ns.Auras.Apply(view)
	env._restricted = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	assert(nested and #env._errors == 0 and K.ErrorCount() == 0,
		"drain a snapshot of pending aura restyles so a nested Apply cannot invalidate its iterator: " .. table.concat(env._errors, "\n"))
end

print("ok aura style switches match fresh tiles and keep icons above dispel tint")
