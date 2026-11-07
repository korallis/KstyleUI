-- test-spike.lua: the spike addon loads offline, logs runs, and its spikes record results without erroring.
local SpikeEnv = dofile("Tools/regression/spike_env.lua")

local ROOT = "Tools/spikes/KstyleUI_Spike"

local function readFile(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

local function near(a, b, what)
	assert(type(a) == "number" and math.abs(a - b) < 1e-6, what .. ": expected " .. b .. ", got " .. tostring(a))
end

-- The TOC carries the Global Constraints header without ## Group, and saves the run log.
local toc = readFile(ROOT .. "/KstyleUI_Spike.toc")
assert(toc:find("## Interface: 16001", 1, true), "TOC needs ## Interface: 16001")
assert(toc:find("## AllowLoadGameType: camelot", 1, true), "TOC needs ## AllowLoadGameType: camelot")
assert(toc:find("## SavedVariables: KstyleUISpikeDB", 1, true), "TOC must save KstyleUISpikeDB")
assert(not toc:find("## Group", 1, true), "the spike stays out of the KstyleUI group")

-- Every <Font> in Spike.xml points at a font file that exists, and asks for slug rendering.
local xml = readFile(ROOT .. "/Spike.xml")
local fonts = 0
for attrs in xml:gmatch("<Font%s([^>]*)>") do
	fonts = fonts + 1
	local file = assert(attrs:match('font="Interface\\AddOns\\KstyleUI_Spike\\([^"]+)"'), "font path must be inside the addon")
	assert(io.open(ROOT .. "/" .. file:gsub("\\", "/"), "rb"), "missing font file " .. file)
	assert(attrs:find('slug="true"', 1, true), "XML fonts exist to test slug rendering")
end
assert(fonts == 12, "expected 12 XML slug fonts (3 fonts x 4 sizes), got " .. fonts)

-- Loading registers /kspike and nothing runs until a command asks.
local env, ns = SpikeEnv()
assert(env.SLASH_KSPIKE1 == "/kspike" and type(env.SlashCmdList.KSPIKE) == "function", "/kspike not registered")
assert(#env.Runs() == 0, "no spike may run at load")
assert(rawget(_G, "KstyleUISpikeDB") == nil, "addon code leaked into the real globals")

-- /kspike list names every spike.
env.Slash("list")
for _, name in ipairs({ "fonts", "scale", "encoding", "textures" }) do
	assert(ns.spikes[name], "spike not registered: " .. name)
	assert(env.ChatHas(name), "/kspike list does not show " .. name)
end

-- An unknown name says so and logs nothing.
env.Slash("nope")
assert(env.ChatHas("unknown spike: nope") and #env.Runs() == 0, "unknown spikes must not log a run")

-- Pixel maths from the spec's Scaling table.
near(ns.RootScale(1, 1), 768 / 1080, "root scale at UI scale 1")
near(ns.RootScale(0.64, 1.25), 768 / 1080 / 0.64 * 1.25, "root scale with UI scale and user scale")
for _, case in ipairs({ { 1080, 1 }, { 1440, 1 }, { 2160, 2 }, { 2234, 2 } }) do
	assert(ns.BorderPixels(case[1]) == case[2], "border at " .. case[1] .. " lines should be " .. case[2] .. " px")
end
near(ns.PixelUnits(1, 2160, 1), 0.5, "one pixel at 2160 lines")
near(ns.PixelUnits(2, 2234, 1), 2 * 1080 / 2234, "two pixels at 2234 lines")
near(ns.PixelUnits(1, 1080, 1.25), 1 / 1.25, "one pixel at user scale 1.25")

-- DeepEqual names the first difference.
assert(ns.DeepEqual({ a = { 1, 2 }, b = "x" }, { a = { 1, 2 }, b = "x" }))
local same, path = ns.DeepEqual({ a = { 1, 2 } }, { a = { 1, 3 } })
assert(not same and path == "a.2", "DeepEqual path: " .. tostring(path))
same, path = ns.DeepEqual({ a = 1 }, { a = 1, extra = true })
assert(not same and path == "extra", "DeepEqual must notice extra keys: " .. tostring(path))

-- Describe never compares or indexes a secret.
assert(ns.Describe(env.Secret(5)) == "<secret>")
assert(ns.Describe(5) == 5 and ns.Describe("a") == "a" and ns.Describe(true) == true and ns.Describe(nil) == nil)
assert(ns.Describe({}) == "<table>" and ns.Describe(print) == "<function>")

-- A run records the spike, the time, the build and its results, and caps its lists.
local run = ns.NewRun("test", "unit")
assert(run.data.spike == "test" and run.data.build == "1.60.1.70840" and run.data.time == 1762480000)
assert(run.data.origin == "unit" and type(run.data.results) == "table")
assert(env.LastRun() == run.data, "a run is appended to KstyleUISpikeDB.runs")
for i = 1, ns.MAX_ENTRIES + 5 do
	run:Add("events", { i = i })
end
assert(#run.data.results.events == ns.MAX_ENTRIES and run.data.results.eventsDropped == 5, "lists are capped")
run:Set("hp", env.Secret(10))
assert(run.data.results.hp == "<secret>", "a secret is never stored")

-- encoding: every function exists and a profile round-trips through the export pipeline.
env.Slash("encoding")
local enc = env.LastRun().results
assert(env.LastRun().spike == "encoding")
for _, name in ipairs({ "SerializeCBOR", "DeserializeCBOR", "CompressString", "DecompressString", "EncodeBase64", "DecodeBase64" }) do
	assert(enc.exists[name] == true, "encoding: " .. name .. " not recorded as present")
end
assert(enc.roundTrip == true, "encoding: round trip failed at " .. tostring(enc.mismatch or enc.error))
assert(enc.prefix == "KSUI1:", "encoding: export string must start with KSUI1:")
assert(enc.rejectsGarbage ~= nil, "encoding: record what import does with a hostile string")

-- encoding without C_EncodingUtil records the gap instead of erroring.
local bare = SpikeEnv({ remove = { "C_EncodingUtil" } })
bare.Slash("encoding")
assert(bare.LastRun().results.exists.SerializeCBOR == false and bare.LastRun().results.roundTrip == "unavailable")

-- scale: on the Mac's 3456x2234 screen the root is 1080 units tall and borders are 2 px.
local mac, macNs = SpikeEnv({ width = 3456, height = 2234 })
mac.Slash("scale")
local sc = mac.LastRun().results
assert(sc.physicalWidth == 3456 and sc.physicalHeight == 2234)
near(sc.rootEffectiveScale, 768 / 1080, "root effective scale")
near(sc.expectedRootHeight, 1080, "root height in units")
near(sc.pixelUnits, 1080 / 2234, "pixel size in units")
assert(sc.borderPixels == 2, "Mac border is 2 px")
assert(macNs.active.scale, "scale watches for blocked actions while active")
mac.FireEvent("ADDON_ACTION_BLOCKED", "KstyleUI_Spike", "Frame:SetScale()")
mac.FireEvent("DISPLAY_SIZE_CHANGED")
mac.RunTimers()
mac.FireEvent("ADDON_ACTION_FORBIDDEN", "KstyleUI_Spike", "late")
assert(sc.blocked == 1 and sc.forbidden == 0, "only actions inside the 60 s window count")
assert(sc.finished == true and not macNs.active.scale, "scale stops after its window")
local sawResize = false
for _, e in ipairs(sc.events) do
	sawResize = sawResize or e.event == "DISPLAY_SIZE_CHANGED"
end
assert(sawResize, "scale records display changes and reapplies the root scale")

-- scale with a user scale argument.
mac.Slash("scale 1.25")
near(mac.LastRun().results.userScale, 1.25, "user scale argument")
near(mac.LastRun().results.expectedRootHeight, 1080 / 1.25, "root height at user scale 1.25")

-- fonts: 3 fonts x 4 sizes x 3 variants, each with what GetFont reported.
env.Slash("fonts")
local samples = env.LastRun().results.samples
assert(#samples == 36, "fonts: expected 36 samples, got " .. #samples)
local seen = {}
for _, s in ipairs(samples) do
	seen[s.font .. "/" .. s.size .. "/" .. s.variant] = true
	assert(s.ok == true, "fonts: " .. s.font .. " " .. s.size .. " " .. s.variant .. " did not apply")
	assert(s.height == s.size, "fonts: GetFont height must be recorded")
end
for _, key in ipairs({ "SourceSans3-Semibold/9/plain", "SourceSans3-Regular/16/SLUG", "Inter-SemiBold/24/xmlSlug" }) do
	assert(seen[key], "fonts: missing sample " .. key)
end

-- Panels take their own screenshot a moment after they open, since a Mac keyboard has no Print Screen key.
local fontsRun = env.LastRun()
assert(env.screenshots == 0, "the screenshot waits until the panel has drawn")
env.RunTimers()
assert(env.screenshots == 1 and #fontsRun.results.screenshots == 1, "fonts takes one screenshot")
env.Slash("shot")
assert(env.screenshots == 2, "/kspike shot takes a screenshot")

-- textures: both PNGs load as textures and as masks.
env.Slash("textures")
env.RunTimers()
local tex = env.LastRun().results
for _, key in ipairs({ "mask", "alpha", "maskedByAlpha", "maskedByMask" }) do
	assert(tex.textures[key] and tex.textures[key].setReturn ~= nil, "textures: no SetTexture result for " .. key)
	assert(tex.textures[key].texture ~= nil, "textures: GetTexture() not recorded for " .. key)
end
assert(tex.measured == true, "textures: results are read one frame later")

-- basic starts the spikes in its group a few seconds apart, so each panel gets its own screenshot.
local before, shotsBefore = #env.Runs(), env.screenshots
env.Slash("basic")
assert(#env.Runs() - before == 1, "basic starts one spike at a time")
env.RunTimers()
assert(#env.Runs() - before >= 4, "basic runs fonts, scale, encoding and textures")
assert(env.screenshots - shotsBefore == 3, "fonts, scale and textures each take a screenshot")
local shown = 0
for _, panel in pairs(ns.panels) do
	shown = shown + (panel:IsShown() and 1 or 0)
end
assert(shown == 1, "opening a panel closes the others, got " .. shown .. " open")
env.Slash("stop")
assert(next(ns.active) == nil, "stop ends every active spike")

-- stop also cancels the group launches that have not started yet.
local quick = SpikeEnv()
quick.Slash("basic")
quick.Slash("stop")
quick.RunTimers()
assert(#quick.Runs() == 1, "stop must cancel queued group launches, got " .. #quick.Runs() .. " runs")
assert(quick.screenshots == 0, "a stopped group takes no more screenshots")

-- hide closes every panel the spikes opened.
env.Slash("hide")
for _, panel in pairs(ns.panels) do
	assert(not panel:IsShown(), "hide must close every panel")
end

print("spike ok")
