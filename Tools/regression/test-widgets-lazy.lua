-- test-widgets-lazy.lua: unused chrome and effects allocate no regions, and first use preserves eager state.
local W = dofile("Tools/regression/widget_env.lua")

local function count(env)
	local n = 0
	for _, frame in ipairs(env._frames) do
		n = n + #frame._regions
	end
	return n
end

do
	local env, K = W.New()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	local child = env.CreateFrame("Frame", nil, parent)
	local calls = ""
	child:SetScript("OnShow", function() calls = calls .. "original " end)
	child:HookScript("OnShow", function() calls = calls .. "hook " end)
	parent:Hide(); child:Hide(); child:Show()
	assert(calls == "", "showing a child of a hidden parent must defer OnShow")
	parent:Show(); parent:Show(); child:Show()
	assert(calls == "original hook ", "OnShow must run the original then its hook once when the parent becomes visible")
	parent:Hide()
	local chrome = K.Widgets.Chrome(child)
	local T = dofile("Tools/regression/tooltips_env.lua")
	T.BlizzardShow(parent, true)
	assert(chrome.fill, "BlizzardShow must deliver child OnShow so lazy tooltip art appears")
	local S = dofile("Tools/regression/skins_env.lua")
	local window, shows = env.CreateFrame("Frame", nil, K.Scale.Root()), 0
	window:Hide()
	window:SetScript("OnShow", function() shows = shows + 1 end)
	S.Show(window)
	assert(shows == 1, "skins_env.Show must let the stub deliver OnShow once without firing it twice")
end

do
	local env, K = W.New()
	local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
	owner:Hide()
	local before = count(env)
	local chrome = K.Widgets.Chrome(owner)
	chrome:SetFillRGBA(0.2, 0.3, 0.4, 0.5)
	chrome:SetEdgeRGBA(0.6, 0.7, 0.8, 0.9)
	chrome:SetProc(true)
	chrome:SetHeader(25)
	assert(count(env) == before and not chrome.fill, "hidden Chrome must defer its 36 slice textures and six ticks until shown")
	owner:Show()
	assert(chrome.fill and count(env) >= before + 33, "OnShow must build the visible Chrome groups before drawing")
	assert(#chrome.shadow == 0, "P3: keep the disabled shadow slice unbuilt")
	assert(W.SameColor(chrome.fill[5], 0.2, 0.3, 0.4, 0.5), "first show must apply the stored fill")
	local built = count(env)
	owner:Hide(); owner:Show(); chrome:Restyle()
	assert(count(env) == built, "Chrome must build only once")
	local hidden = env.CreateFrame("Frame", nil, K.Scale.Root())
	hidden:Hide()
	local hiddenChrome = K.Widgets.Chrome(hidden)
	hiddenChrome:SetShown(false)
	hidden:Show()
	assert(not hiddenChrome.fill, "a hidden Chrome must keep its wanted visibility when its owner appears")
	hiddenChrome:SetShown(true)
	assert(hiddenChrome.fill[5]:IsShown(), "the first Chrome show must build its art")

	local glow = K.Widgets.Glow(owner, { kind = "selection" })
	before = count(env)
	glow:SetColorRGB(0.2, 0.4, 0.6)
	glow:SetIntensity(0)
	glow:Restyle()
	assert(count(env) == before and not rawget(glow, "slice"), "an unused glow must defer all nine shadow textures")
	glow:SetIntensity(0.5)
	assert(count(env) == before + 9 and W.SameRGB(glow.slice[5], 0.2, 0.4, 0.6), "first intensity must apply the stored glow colour")
	glow:Start(); glow:Stop(); glow:Start()
	assert(count(env) == before + 9, "glow restarts must reuse the slice")
	local custom = K.Widgets.Glow(owner, { kind = "selection" })
	before = count(env)
	custom.slice[5]:Hide()
	custom:SetIntensity(1)
	assert(count(env) == before + 9 and not custom.slice[5]:IsShown(), "explicit slice customisation must build once and preserve the hidden centre")

	local slot = K.Widgets.Slot(K.Scale.Root())
	assert(not slot.hoverRim and not slot.pressRim and not slot.lumenGlow.texture, "an idle slot must defer its 27 hover, press and proc textures")
	before = count(env)
	W.Enter(slot)
	assert(count(env) == before + 5, "first hover must build exactly four rim pieces and one wash")
	W.Down(slot)
	assert(count(env) == before + 18, "first press must add exactly eight halo pieces, four rim pieces and one wash")
	slot:SetProc(true)
	assert(count(env) == before + 27, "first proc must add exactly eight halo pieces and the inner glow")
	W.Leave(slot); W.Enter(slot); slot:SetProc(false); slot:SetProc(true); slot:Flash()
	assert(count(env) == before + 27, "repeated slot effects must reuse every region")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
end

local REGION = { Texture = true, FontString = true, MaskTexture = true, Line = true }
local function snapshot(owner, chrome, glow)
	local names, regions = {}, {}
	local function name(object, key)
		if object then
			names[object] = key
			if REGION[object._type] then regions[key] = object end
		end
	end
	local function frames(frame, key)
		name(frame, key)
		local n = 0
		for _, child in ipairs(frame._kids) do
			if not REGION[child._type] and child._type ~= "AnimationGroup" then
				n = n + 1
				frames(child, key .. "/" .. n)
			end
		end
	end
	frames(owner, "owner")
	name(owner:GetParent(), "parent")
	for _, key in ipairs({ "icon", "mask", "well", "bevelTop", "bevelBottom", "hotkey", "count", "countdown", "readyWash" }) do
		name(owner[key], key)
	end
	for _, key in ipairs({ "shadow", "fill", "rim", "line", "gilt", "bevel", "header" }) do
		for i, region in ipairs(chrome[key] or {}) do name(region, "chrome/" .. key .. i) end
	end
	for _, key in ipairs({ "innerLine", "hoverRim", "pressRim", "pressHalo", "procHalo" }) do
		for i, region in ipairs(owner[key] or {}) do name(region, key .. i) end
	end
	name(owner.lumenGlow and owner.lumenGlow.texture, "procTexture")
	for i, region in ipairs(glow.slice) do name(region, "glow/slice" .. i) end
	for _, key in ipairs({ "spark", "sparkCross", "core" }) do name(glow[key], "glow/" .. key) end
	local function remaining(frame)
		for i, region in ipairs(frame._regions) do
			if not names[region] then name(region, names[frame] .. "/region" .. i) end
		end
		for _, child in ipairs(frame._kids) do
			if names[child] and not REGION[child._type] then remaining(child) end
		end
	end
	remaining(owner)
	local function encode(value)
		if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
		if names[value] then return "@" .. names[value] end
		assert(not value._env, "snapshot needs a semantic name for " .. tostring(value._type))
		local parts = {}
		for key, item in pairs(value) do parts[#parts + 1] = tostring(key) .. "=" .. encode(item) end
		table.sort(parts)
		return "{" .. table.concat(parts, ",") .. "}"
	end
	local out = {}
	for key, region in pairs(regions) do
		out[key] = encode({ points = region._points, width = region:GetWidth(), height = region:GetHeight(),
			state = region._state, alpha = region:GetAlpha(), shown = region:IsShown() })
	end
	for object, key in pairs(names) do
		if not REGION[object._type] then
			local order = {}
			for _, region in ipairs(object._regions) do
				local layer = encode(region._state.DrawLayer)
				order[layer] = order[layer] or {}
				order[layer][#order[layer] + 1] = names[region]
			end
			out["draw order/" .. key] = encode(order)
		end
	end
	return out
end

local function exercise(lazy)
	local env, K = W.New()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	if lazy then parent:Hide() end
	local slot = K.Widgets.Slot(parent, { size = 36, icon = 135489 })
	local chrome = slot.chrome
	local glow = K.Widgets.Glow(slot)
	if not lazy then
		slot:BuildState("hover"); slot:BuildState("press"); slot:BuildState("proc")
		glow:Build()
	end
	chrome:SetFillRGBA(0.3, 0.2, 0.1, 0.7)
	chrome:SetEdgeRGBA(0.4, 0.5, 0.6, 0.8)
	chrome:SetShadow(true)
	glow:SetColorRGB(0.6, 0.3, 0.1)
	slot:SetSize(43, 39)
	parent:Show()
	W.Enter(slot); W.Down(slot); slot:SetProc(true); glow:Start()
	env.RunTimers()
	local first = snapshot(slot, chrome, glow)
	slot:Restyle(); chrome:Restyle(); glow:Restyle()
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
	local final = snapshot(slot, chrome, glow)
	for key, state in pairs(first) do final["first use/" .. key] = state end
	return final
end

local function card(lazy)
	local env, K = W.New({ setup = function(e)
		e.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
	end })
	local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
	owner:SetSize(240, 150)
	if lazy then owner:Hide() end
	local chrome = K.Widgets.Chrome(owner, { shape = "panel", shadow = true })
	local glow = K.Widgets.Glow(owner)
	if not lazy then glow:Build() end
	chrome:SetFill("surface", 0.8)
	chrome:SetHeader(30)
	chrome:SetEdgeRGBA(0.4, 0.3, 0.2, 0.7)
	glow:SetColor("epic")
	owner:Show(); glow:Start()
	env.RunTimers()
	owner:SetSize(260, 170)
	chrome:SetHeader(35)
	chrome:Restyle(); glow:Restyle()
	assert(chrome.bevel and chrome.headerSplit, "the card comparison must include the steel bevel and header")
	assert(#env._errors == 0, table.concat(env._errors, "\n"))
	return snapshot(owner, chrome, glow)
end

local function same(eager, lazy, what)
	for key, state in pairs(eager) do assert(lazy[key] == state, what .. " lazy state differs: " .. key .. "\n" .. state .. "\n" .. tostring(lazy[key])) end
	for key in pairs(lazy) do assert(eager[key], "lazy widget added an extra region: " .. key) end
end

local function firstGlow(lazy, kind)
	local env, K = W.New()
	local owner = env.CreateFrame("Frame", nil, K.Scale.Root())
	owner:SetSize(32.2, 24.3)
	local glow = K.Widgets.Glow(owner, { kind = kind, core = 0.2 })
	if not lazy then glow:Build() end
	glow:SetColorRGB(0.2, 0.4, 0.6)
	owner:SetSize(64.4, 48.6)
	owner:SetScale(1.25)
	glow:Start()
	return snapshot(owner, {}, glow)
end

for _, kind in ipairs({ "proc", "selection" }) do
	same(firstGlow(false, kind), firstGlow(true, kind), kind .. " first Start before a later restyle")
end

same(exercise(false), exercise(true), "medallions slot")
same(card(false), card(true), "medallions card")

do
	local env, K = W.New()
	local owner = env.CreateFrame("Button", nil, K.Scale.Root(), "SecureActionButtonTemplate")
	owner.IsProtected = function() return true end
	owner:Hide()
	local chrome = K.Widgets.Chrome(owner)
	assert(chrome.fill, "protected Chrome must prebuild out of combat so its first combat show keeps every pixel")
	local before = count(env)
	env.SetCombat(true)
	for _, method in ipairs({ "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints", "SetSize", "SetScale", "SetParent", "SetFrameLevel" }) do
		owner[method] = function() error("protected frame mutation during combat: " .. method) end
	end
	owner._shown = true
	owner:GetScript("OnShow")(owner)
	chrome:SetFillRGBA(0.2, 0.3, 0.4, 0.5)
	assert(count(env) == before and W.SameColor(chrome.fill[5], 0.2, 0.3, 0.4, 0.5), "first combat show must reuse the prepared art without touching its protected owner")
	env.SetCombat(false)
end

do
	local original, measured = dofile, nil
	_G.dofile = function(path)
		local result = original(path)
		if path == "Tools/render/scenes/_common.lua" then
			local force = result.ForceScreen
			result.ForceScreen = function(env, ...)
				measured = env
				return force(env, ...)
			end
		end
		return result
	end
	local screen, lib = _G.RENDER_SCREEN, _G.RENDER_SCENE_LIB
	_G.RENDER_SCREEN = { width = 5120, height = 1440, size = "auto" }
	_G.RENDER_SCENE_LIB = true
	local Hud = dofile("Tools/render/scenes/hud.lua")
	local limits = { unitframes = 4300, actionbars = 4900, databars = 1400, tooltips = 300 }
	for _, module in ipairs({ "unitframes", "actionbars", "databars", "tooltips" }) do
		local scene = Hud.Module(module, Hud.Options({ layout = "DPS", class = "ROGUE", applyPreset = true }))
		local created = count(assert(measured))
		assert(created <= limits[module], module .. " creates " .. created .. " regions; defer unused chrome and state layers")
		assert(#scene.items > 0, module .. " must actually draw the HUD fixture")
		assert(#measured._errors == 0, table.concat(measured._errors, "\n"))
		print("lazy regions " .. module .. ": " .. created)
	end
	-- A healer, hunter, mage or warlock with every crest tracker known and lit (the render harness's RENDER_TRACKERS=lit
	-- story) starts from the action bar regions staging created before its crest broke out of its sockets (b4ec7887b), and
	-- each class's ceiling below adds only the regions named here for the layers and auras chosen since; a lit Rogue is 5,063,
	-- so 4,900 holds only the stock fixture above. A hunter's forged marks each add a solid body, and
	-- the perched and emblem ones a shadow and a halo (49 regions); each of the six Sting marks, drawn at 24 units so it
	-- reads, adds a shadow, a halo and two dark shades (24 regions), and each lit Aspect but the Hawk a dark silhouette
	-- over the unlit hawk (6 regions), which takes its limit from 4,915 to 4,980. The hunter,
	-- warlock, shaman and druid sit above that by the layers their owner chose to add so that a motion level changed in combat
	-- shows at once and an older cue hides under a newer one: a second flare slot on each aura medal, two more copies of the
	-- slots of each piece with a cue on its own art (a warlock's torment spires and the hunter's gust among them), and a moving
	-- and a still copy of the storm's halo and sparks and of a druid's Clearcasting leaves. Those two copies of a hunter's
	-- cued pieces carry their forged marks too, hidden, which adds 115 regions to the hunter's 70 for the motion layers.
	-- The lit story's pet is Content, so the hunter also builds the haunch its pet mood mark draws (a body, a sheen, a shadow
	-- and a halo) in place of the old one-region ember: 3 more. A happy pet never builds it.
	-- The hunter's crest rail burns each seat with an animated aura, as the captain asked: a still and a burning copy on each seat, a glint,
	-- a steel sigil that stays readable while the seat cools, and on each crowned major a signal, a last-fifth notch and the crown's own
	-- burning aura. The cooldown row keeps one sigil per crowned buff and hides the ones the rail seats (one piece, not one per combination),
	-- so together they take the hunter's limit from 5,168 to 5,222. The rail then came to the mage and the warlock, and every
	-- class's rail gained a second rail of smaller medals for the long cooldowns past the four seats and the racial (27
	-- regions on the lit hunter).
	-- The potion sigil every class's rail carries burns as an aura (a fire, a still and its figure drawn black beneath, in
	-- place of one flat texture): 2 more for each class, and the druid's Dash sigil does the same on each of its form rails: 12.
	-- The mage's and warlock's marks, cooldown sigils and soul wisps burn as auras the same way, as the captain asked: a fire and a
	-- still in place of each flat glyph, a seated one over a socket plate, and each perch or fuse head an aura slot feeds adds a
	-- transparent copy of its still for the Calm arrival cue. That takes the mage from 4,925 to 4,953 and the warlock, whose five
	-- curse heads, four spire feet and live and sacrificed demon sheets are each their own aura, from 5,099 to 5,227.
	-- The hunter's new homes take it from 5,224 to the measured 5,350: the pet's family ability perch lights a cooldown and two ringed aura feeds (the pet's debuff
	-- on the target and Furious Howl), each aura feed with its two motion copies (114 regions), the potion pendant (12), Growl's orders and
	-- the tracking mark's still glyphs (4 each), the range ring and the pet's focus bar, less the forged bodies the tracking mark gave up.
	-- Tranquilizing Shot's glyph on the lower left foot is part of that total.
	-- Each signature pop-off the lit story knows (SlabPopoffs.lua) adds 10, its Blender sheet once in each motion face among
	-- them, and Power Infusion's target and focus slots 16 more, each with the sheet, ring, late warning and flare the priest's own
	-- slot has. The warlock knows two, the mage and priest one, and the hunter none.
	local getenv = os.getenv
	rawset(os, "getenv", function(name) return name == "RENDER_TRACKERS" and "lit" or getenv(name) end)
	for class, limit in pairs({ PRIEST = 4968, DRUID = 5280, SHAMAN = 4919, HUNTER = 5350, MAGE = 4963, WARLOCK = 5247 }) do
		Hud.Module("actionbars", Hud.Options({ layout = "DPS", class = class, applyPreset = true }))
		local created = count(assert(measured))
		assert(created <= limit and #measured._errors == 0, class .. " lit creates " .. created .. " action bar regions, over " .. limit .. "; share or defer its crest pieces")
		print("lazy regions actionbars lit " .. class .. ": " .. created)
	end
	rawset(os, "getenv", getenv)
	_G.dofile = original
	_G.RENDER_SCREEN, _G.RENDER_SCENE_LIB = screen, lib
end

print("widgets lazy ok")
