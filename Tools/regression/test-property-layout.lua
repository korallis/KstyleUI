-- test-property-layout.lua: at random screens from 1024 x 768 to 7680 x 2160 (4:3 to 32:9), Interface sizes, HUD widths, all three HUD styles, both arrangements, the DPS, Tank and Healer layouts and random optional bars, every element Layout places from its defaults lies on screen with its edges on whole physical pixels, and no two elements the fit check keeps apart overlap, the orbs, the Medallions hub and the quest card included.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Property = dofile("Tools/regression/property_lib.lua")

local RATIOS = { 4 / 3, 3 / 2, 16 / 10, 16 / 9, 64 / 27, 43 / 18, 32 / 9 }
local EPS = 1e-6
local ORBS_EDGE = 2

local probe, PK = CoreEnv.New({})
CoreEnv.Boot(probe)
local DB_VERSION, ELEMENTS, Settings = PK.Store.DB_VERSION, PK.Setup.Layouts.ELEMENTS, PK.Setup.Layouts.Settings

local function Generate(g)
	local ratio = g:bool(0.7) and g:pick(RATIOS) or g:float(4 / 3, 32 / 9)
	local height = g:int(768, 2160)
	local width = math.floor(height * ratio + 0.5)
	if width > 7680 then
		width = 7680
		height = math.floor(width / ratio + 0.5)
	end
	return {
		width = math.max(1024, width), height = height,
		preset = g:pick({ "DPS", "Tank", "Healer" }), style = g:pick({ "frames", "orbs", "medallions" }),
		arrangement = g:pick({ "centred", "spread" }), canvas = g:pick({ "21:9", "16:9", "full" }),
		size = (not g:bool(0.4)) and g:float(0.6, 1.5) or nil,
		bars = { bar3 = g:bool(0.3), bar4 = g:bool(0.7), bar5 = g:bool(0.7), bar6 = g:bool(0.3) },
		threat = g:bool(0.5),
	}
end

local function Show(c)
	local bars = {}
	for _, bar in ipairs({ "bar3", "bar4", "bar5", "bar6" }) do
		if c.bars[bar] then
			bars[#bars + 1] = bar
		end
	end
	return string.format("%dx%d %s %s %s, HUD width %s, size %s (applied %s, fit cap %s), bars 1, 2%s, threat meter %s", c.width, c.height, c.preset,
		c.style, c.arrangement, c.canvas, c.size and string.format("%.4f", c.size) or "automatic", c.applied and string.format("%.15g", c.applied) or "?",
		c.cap and string.format("%.15g", c.cap) or "?", #bars > 0 and (", " .. table.concat(bars, ", ")) or "", c.threat and "on" or "off")
end

-- The saved profile a player who picked the layout in setup has: every module on, the preset's settings, then the case's choices.
local function Profile(c)
	local profile = {
		Appearance = { uiScale = c.size or 1, uiScaleAuto = c.size == nil },
		Layout = { preset = c.preset, arrangement = c.arrangement, canvas = c.canvas },
		HudStyle = { style = c.style },
	}
	for _, element in ipairs(ELEMENTS) do
		profile[element.module] = { enabled = true }
	end
	for _, entry in ipairs(Settings(c.preset)) do
		local node = profile[entry.module]
		local parts = {}
		for part in entry.key:gmatch("[^.]+") do
			parts[#parts + 1] = part
		end
		for i = 1, #parts - 1 do
			node[parts[i]] = node[parts[i]] or {}
			node = node[parts[i]]
		end
		node[parts[#parts]] = entry.value
	end
	for bar, on in pairs(c.bars) do
		profile.ActionBars[bar] = profile.ActionBars[bar] or {}
		profile.ActionBars[bar].enabled = on
	end
	profile.Meters.followRole = false
	profile.Meters.threat = { shown = c.threat }
	return profile
end

local function Whole(v)
	return math.abs(v - math.floor(v + 0.5)) < EPS
end

local function Overlap(r, s)
	return r[1] < s[3] - EPS and s[1] < r[3] - EPS and r[2] < s[4] - EPS and s[2] < r[4] - EPS
end

local function CircleMeets(o, r)
	local x = math.max(r[1], math.min(o.x, r[3]))
	local y = math.max(r[2], math.min(o.y, r[4]))
	return (o.x - x) ^ 2 + (o.y - y) ^ 2 < (o.radius - EPS) ^ 2
end

-- Place(c) boots the core at the case's screen and profile, registers a stand-in of each enabled element's footprint the way its
-- module does, and returns each placed rect in physical pixels from the screen's bottom-left, plus the orbs as circles.
local function Place(c)
	local env, K = CoreEnv.New({
		width = c.width, height = c.height, uiScale = 768 / 1080, size = "auto", fit = true,
		saved = { version = DB_VERSION, account = { setupSeen = true }, profiles = { Default = Profile(c) } },
		setup = function(e)
			e.GetPhysicalScreenSize = function()
				return c.width, c.height
			end
		end,
	})
	CoreEnv.Boot(env)
	local Layouts, Layout, Scale, Widgets = K.Setup.Layouts, K.Layout, K.Scale, K.Widgets
	assert(K.HudStyle.Current() == c.style and Layout.Setting("preset") == c.preset and Scale.Arrangement() == c.arrangement, "the saved choices load")
	local pixel, origin = Scale.Pixel(1), Scale.Origin()
	local rects, orbs = {}, {}
	local function Add(key, left, bottom, w, h, offsetX)
		local l, b = (origin + left) / pixel, bottom / pixel
		local r, t = l + w / pixel, b + h / pixel
		local dx = (offsetX or 0) / pixel
		rects[#rects + 1] = { l + dx, b, r + dx, t, key = key, edges = { l, b, r, t } }
	end
	local enabled = Layouts.Enabled(c.preset, K.Store.Profile())
	for _, element in ipairs(ELEMENTS) do
		local key = element.key
		if enabled[key] and not (c.style == "orbs" and key == "unitframes.player") then
			local w, h, offsetX = Layouts.Footprint(c.preset, key)
			local styled = c.style ~= "frames" and Layouts.Style(c.style, c.preset, key)
			if styled and styled.width then
				w, h, offsetX = styled.width, styled.height, nil
			end
			if c.style == "orbs" and key == "actionbars.bar2" then
				w = w + Layouts.SPLIT_GAP
			end
			local grouped, groupHeight = Layouts.StyleSize(c.style, Scale.Aspect(), key)
			if grouped then
				w, h, offsetX = grouped, groupHeight, nil
			end
			-- Register the visible body; add its outer reserve once after the live clamp.
			local bodyW, bodyH = w, h
			if element.reserve and not (styled and styled.width or grouped) then bodyW, bodyH = element.width, element.height end
			local frame = env.CreateFrame("Frame", nil, Scale.Root())
			frame:SetSize(bodyW, bodyH)
			Layout.Register(frame, key, Layouts.Default(key), { label = key, module = element.module, scalable = true })
			Widgets.Size(frame, bodyW, bodyH)
			if key == "meters.threat" and enabled["meters.damage"] ~= false then
				local paired = Layouts.PrepareFits(c.preset, Scale.CanvasWidth(c.width, c.height), c.height, enabled, nil, c.style).layout[key]
				assert(Layout.Update(key, paired))
				h = select(2, Layouts.Footprint(c.preset, "meters.damage"))
				bodyH = h
				Widgets.Size(frame, bodyW, bodyH)
			end
			local left, bottom, fw, fh = Layout.Rect(key)
			local fx, fy = Layout.Geometry.Fraction(Layout.Get(key).anchor)
			local reserveW, reserveH = Scale.Snap(w - bodyW), Scale.Snap(h - bodyH)
			Add(key, left - reserveW * fx, bottom - reserveH * fy, fw + reserveW, fh + reserveH, offsetX)
			rects[#rects].edges = { (origin + left) / pixel, bottom / pixel, (origin + left + fw) / pixel, (bottom + fh) / pixel }
			if key == "actionbars.bar1" and c.style == "orbs" then
				local art = Layouts.OrbsTray(fw)
				local rw, rh = Layout.RootSize()
				local reach, low = art.ringX + art.ring / 2 + ORBS_EDGE, art.ring / 2 + ORBS_EDGE
				local cx = math.min(math.max(left + fw / 2, reach), rw - reach)
				local cy = math.min(math.max(bottom + fh / 2, low - art.lift), rh - low - art.lift) + art.lift
				orbs[1] = { key = "orbs.health", x = (origin + cx - art.ringX) / pixel, y = cy / pixel, radius = art.ring / 2 / pixel }
				orbs[2] = { key = "orbs.power", x = (origin + cx + art.ringX) / pixel, y = cy / pixel, radius = art.ring / 2 / pixel }
			end
		end
	end
	local bar1, bar2
	for _, r in ipairs(rects) do
		bar1 = r.key == "actionbars.bar1" and r or bar1
		bar2 = r.key == "actionbars.bar2" and r or bar2
	end
	if c.style == "medallions" and bar1 and bar2 then
		local ring = Layouts.MEDALLIONS_RING / pixel
		local cx, top = (bar1[3] + bar2[1]) / 2, math.max(bar1[4], bar2[4])
		rects[#rects + 1] = { cx - ring / 2, top - ring / 2, cx + ring / 2, top + ring / 2, key = "medallions.hub", edges = {} }
	end
	local rw, rh = Layout.RootSize()
	local spec, sized = Layouts.Story(c.preset, rh, false, nil, rw).quests, Layouts.Story(c.preset, rh, false, c.style, rw).quests
	local holder = env.CreateFrame("Frame", nil, Scale.Root())
	holder:SetSize(sized.width, sized.height)
	Widgets.Place(holder, spec.key, { anchor = spec.anchor, x = spec.x, y = spec.y }, { label = "Quest card", module = "Skins" })
	local left, bottom, fw, fh = Layout.Rect(spec.key)
	Add(spec.key, left, bottom, fw, fh)
	assert(#env._errors == 0, "the boot raised: " .. tostring(env._errors[1]))
	local canvas, style = Scale.CanvasWidth(c.width, c.height), K.HudStyle.Current()
	c.fitsAtCap = Layouts.Fits(c.preset, canvas, c.height, Scale.MaxUserScale(), enabled, nil, style)
	c.fitsApplied = Layouts.Fits(c.preset, canvas, c.height, Scale.AppliedUserScale(), enabled, nil, style)
	return rects, orbs, Scale.AppliedUserScale(), Scale.MaxUserScale()
end

local function Apart(Layouts, a, b)
	local pair = { [a] = true, [b] = true }
	if pair["groupframes.party"] and pair["groupframes.raid"] then
		return false
	end
	-- The hub's level plaque may cross the experience strip under the slab, as Layouts.Fits allows.
	if pair["medallions.hub"] and pair["databars.xp"] then
		return false
	end
	return Layouts.Dock(a) ~= b and Layouts.Dock(b) ~= a
end

local function Holds(c)
	local rects, orbs, applied, cap = Place(c)
	c.applied, c.cap = applied, cap
	local Layouts = PK.Setup.Layouts
	local out = {}
	local function Fail(text, ...)
		out[#out + 1] = string.format(text, ...)
	end
	for _, r in ipairs(rects) do
		if r[1] < -EPS or r[2] < -EPS or r[3] > c.width + EPS or r[4] > c.height + EPS then
			Fail("%s leaves the screen at %.2f %.2f %.2f %.2f", r.key, r[1], r[2], r[3], r[4])
		end
		for i, edge in ipairs(r.edges) do
			if not Whole(edge) then
				Fail("%s has its %s edge at %.4f px, between physical pixels", r.key, ({ "left", "bottom", "right", "top" })[i], edge)
			end
		end
	end
	for _, o in ipairs(orbs) do
		if o.x - o.radius < -EPS or o.y - o.radius < -EPS or o.x + o.radius > c.width + EPS or o.y + o.radius > c.height + EPS then
			Fail("%s leaves the screen: centre %.1f %.1f, radius %.1f", o.key, o.x, o.y, o.radius)
		end
		for _, r in ipairs(rects) do
			if r.key ~= "actionbars.bar1" and CircleMeets(o, r) then
				Fail("%s overlaps %s", o.key, r.key)
			end
		end
	end
	for i = 1, #rects do
		for j = i + 1, #rects do
			local r, s = rects[i], rects[j]
			if Overlap(r, s) and Apart(Layouts, r.key, s.key) then
				local edge = (r.key == "databars.micro" and s.key == "databars.bags") or (r.key == "databars.bags" and s.key == "databars.micro")
				if not edge or math.min(r[4], s[4]) - math.max(r[2], s[2]) > 1 + EPS then
					Fail("%s overlaps %s", r.key, s.key)
				end
			end
		end
	end
	return #out == 0, out
end

Property.Check({
	name = "layout at any screen",
	script = "Tools/regression/test-property-layout.lua",
	iterations = 60,
	generate = Generate,
	show = Show,
	property = Holds,
	regressions = {
		{ seed = 20261114, case = 52, issue = "LEE-1459" }, { seed = 20261114, case = 113, issue = "LEE-1459" },
		{ seed = 20261114, case = 225, issue = "LEE-1459" }, { seed = 99, case = 22, issue = "LEE-1459" }, { seed = 99, case = 694, issue = "LEE-1459" },
		{ seed = 20261114, case = 18, issue = "LEE-1460" },
		{ seed = 20261114, case = 292, issue = "LEE-1461" },
		{ seed = 777, case = 930, issue = "LEE-1483" }, { seed = 777, case = 988, issue = "LEE-1483" },
		{ seed = 20261114238, case = 422, issue = "LEE-1486" }, { seed = 2026, case = 584, issue = "LEE-1486" },
		{ seed = 20261114238, case = 1040, issue = "LEE-1487" }, { seed = 20261114238, case = 1991, issue = "LEE-1487" },
	},
})
