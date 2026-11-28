-- test-perf-idle-draw.lua: what the idle suite asks the renderer to draw stays bounded: Widgets.HOLLOW lists exactly the sliced textures whose centre texels are transparent, no such centre is shown, nothing runs every frame or writes to a widget once the login fades end (OnUpdate scripts and tickers at their intervals), no animation plays on a hidden owner, and shown regions stay at the counts measured after the hollow-centre cut, also with the rogue's signature pop-off up.
local Suite = dofile("Tools/regression/suite_env.lua")
local Png = dofile("Tools/regression/png.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")
-- Medallions adds 22 drawn regions to its 1710: the suite's combo points light all ten crest jewels and the full ring, so each jewel's rim and glint and the ring's glyphs and halo draw.
local CEILING = { medallions = 1732 }
local SETTLE, WINDOW = 600, 120

local function CheckHollow(K)
	local files = {}
	for name, texels in pairs(K.Widgets.TEXTURE_TEXELS) do
		local path, slice = K.Tokens.Texture(name)
		path = path:gsub("\\", "/"):match("Media/.+$")
		files[path] = files[path] or { Png.Alpha(path) }
		local alpha, w = files[path][1], files[path][2]
		local lo, peak = math.floor(slice * w / texels) - 1, 0
		for y = lo, w - 1 - lo do
			for x = lo, w - 1 - lo do
				peak = math.max(peak, alpha(x, y))
			end
		end
		assert((peak == 0) == (K.Widgets.HOLLOW[name] == true), string.format("%s: its nine-slice centre (plus one texel of filtering reach) peaks at alpha %d; Widgets.HOLLOW (Core/Widgets/Base.lua) lists a sliced texture exactly when that peak is 0", name, peak))
	end
	for name in pairs(K.Widgets.HOLLOW) do
		assert(K.Widgets.TEXTURE_TEXELS[name], "Widgets.HOLLOW names " .. name .. ", which is no sliced texture; list only nine-slice textures whose centre texels are all transparent")
	end
end

local due = {}
local function Frame(env)
	env._now = env._now + 1 / 60
	local busy = false
	for _, f in ipairs(env._frames) do
		local update = f._scripts.OnUpdate
		if update and f:IsVisible() then
			busy = true
			update(f, 1 / 60)
		end
	end
	for _, rec in ipairs(env._auditTickers) do
		if not rec.ticker:IsCancelled() then
			due[rec] = (due[rec] or 0) + 1 / 60
			if due[rec] >= rec.interval then
				due[rec] = due[rec] - rec.interval
				rec.fn(rec.ticker)
			end
		end
	end
	env.RunTimers()
	return busy
end

for _, style in ipairs({ "medallions" }) do
	local env, K = Suite.Prepare(1920, 1080)()
	CheckHollow(K)
	local hollow = {}
	for name in pairs(K.Widgets.HOLLOW) do
		hollow[(K.Tokens.Texture(name))] = name
	end
	local frames, busy = 0, true
	while busy and frames < SETTLE do
		frames = frames + 1
		busy = Frame(env) or W.FinishGroups(env)
	end
	assert(not busy, style .. ": an OnUpdate still runs after " .. SETTLE .. " idle frames; stop per-frame scripts when their work is done (Motion's driver clears its own when no tween runs)")
	local objects, before = {}, {}
	for _, f in ipairs(env._frames) do
		objects[#objects + 1] = f
		for _, r in ipairs(f._regions) do objects[#objects + 1] = r end
	end
	for i, o in ipairs(objects) do before[i] = #o._calls end
	for _ = 1, WINDOW do
		assert(not Frame(env), style .. ": an OnUpdate starts again while the suite is idle; run it only while something changes")
	end
	for i, o in ipairs(objects) do
		for k = before[i] + 1, #o._calls do
			local method = o._calls[k].method
			assert(method:find("^Get") or method:find("^Is") or method:find("^Has") or method:find("^Can"), string.format("%s: a %s gets %s while the suite is idle; a ticker or timer rewrites it with nothing changed, so stop it or write only on change", style, o._type, method))
		end
	end
	local shown = 0
	local function Groups(owner, visible, what)
		for _, group in ipairs(owner._groups or {}) do
			local looping = group:IsPlaying() and group:GetLooping()
			if looping and looping ~= "NONE" then
				assert(visible, style .. ": a " .. looping .. " loop plays on a hidden " .. what .. "; stop it on hide and play it again on show")
				assert(style == "medallions", style .. ": a " .. looping .. " loop plays at idle on a " .. what .. "; Frames and Orbs animate only while something changes")
			end
		end
	end
	for _, f in ipairs(env._frames) do
		local visible = f:IsVisible()
		Groups(f, visible, f._type)
		for _, r in ipairs(f._regions) do
			Groups(r, visible and r._shown ~= false, r._type)
			if visible and r._shown ~= false and r._type ~= "MaskTexture" then
				shown = shown + 1
				local file, coords = r._state.Texture and r._state.Texture[1], r._state.TexCoord
				local centre = coords and coords[1] > 0 and coords[2] < 1 and coords[3] > 0 and coords[4] < 1
				assert(not (hollow[file] and centre), style .. ": the centre piece of a " .. tostring(hollow[file]) .. " nine-slice is shown; its texels are transparent, so ShowSlice and PaintSlice keep it hidden (Core/Widgets/Base.lua)")
			end
		end
	end
	assert(shown <= CEILING[style], string.format("%s: %d shown regions at idle, ceiling %d; build art on first use and hide what draws nothing, or raise the ceiling to the measured count when the new regions are drawn", style, shown, CEILING[style]))
	-- The crest plan keeps the crest under the same ceiling with a signature pop-off up (KstyleUI_ActionBars/SlabPopoffs.lua): the rogue learns Stealth and enters it, its Veil rises and settles, and the suite counts again.
	Slots.Install(env)
	local known = env.C_SpellBook and env.C_SpellBook.IsSpellKnown
	env.C_SpellBook = env.C_SpellBook or {}
	env.C_SpellBook.IsSpellKnown = function(id, bank) return id == 1784 or known ~= nil and known(id, bank) end
	env.FireEvent("SPELLS_CHANGED")
	Slots.Set(env, "player", { { id = 1784, start = env._now } })
	local rising = true
	for _ = 1, SETTLE do
		rising = rising and (Frame(env) or W.FinishGroups(env))
	end
	assert(not rising, style .. ": the Veil pop-off still animates after " .. SETTLE .. " frames")
	local veil
	for _, p in pairs(env._addons.KstyleUI_ActionBars.SlabTrackers.state.forms.crest.pieces) do
		veil = p.spec.key == "crestPopoffs" and p or veil
	end
	assert(veil and veil.lits[1]:IsShown(), style .. ": the rogue's Veil pop-off lights from Stealth")
	local active = 0
	for _, f in ipairs(env._frames) do
		for _, r in ipairs(f:IsVisible() and f._regions or {}) do
			if r._shown ~= false and r._type ~= "MaskTexture" then active = active + 1 end
		end
	end
	assert(active <= CEILING[style], string.format("%s: %d shown regions with the Veil pop-off up, ceiling %d; a pop-off draws its art only while its aura or its fold shows", style, active, CEILING[style]))
	assert(#env._errors == 0 and K.ErrorCount() == 0, style .. ": the idle suite raised " .. tostring(env._errors[1]))
	print(string.format("idle draw ok: %s settles in %d frames, writes nothing for %d more, with %d shown regions, %d with a pop-off up (ceiling %d)", style, frames, WINDOW, shown, active, CEILING[style]))
end
