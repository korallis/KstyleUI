-- test-scalelimit-identity.lua: the optimized search returns the previous implementation's exact double, including its non-monotonic pixel boundaries.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local env, K = CoreEnv.New({ fit = true, size = "auto" })
local Layouts = K.Setup.Layouts
local previous = { L = K.L, Scale = K.Scale, Tokens = K.Tokens }
assert(loadfile("Tools/regression/fixtures/scalelimit-before.lua"))("KstyleUI", previous)
local Before = previous.Setup.Layouts
local screens = { { 5120, 1440 }, { 3440, 1440 }, { 3456, 2234 }, { 2560, 1440 }, { 1920, 1080 } }
local cases = 0

local function Same(a, b)
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not Same(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function Check(name, style, screen, enabled)
	local width, height = screen[1], screen[2]
	local old, oldFits = Before.ScaleLimit(width, height, name, enabled, style)
	local new, newFits = Layouts.ScaleLimit(width, height, name, enabled, style)
	local label = name .. " " .. style .. " " .. width .. "x" .. height
	assert(string.format("%.17g", new) == string.format("%.17g", old),
		label .. ": preserve the exact search result, got " .. string.format("%.17g", new) .. " expected " .. string.format("%.17g", old))
	for _, size in ipairs({ old, old - 1e-6, old + 1e-6, 0.6, 1, 1.5 }) do
		assert(newFits(size) == oldFits(size), label .. ": preserve the fit predicate at " .. string.format("%.17g", size))
	end
	for _, guide in ipairs({ false, true }) do
		for _, shown in ipairs({ false, true }) do
			local rootHeight = 1080 / old
			local rootWidth = width / (height / rootHeight)
			assert(Same(Before.Story(name, rootHeight, guide, style, rootWidth, shown),
				Layouts.Story(name, rootHeight, guide, style, rootWidth, shown)), label .. ": preserve every public Story card field")
		end
	end
	local cached, fits = Layouts.ScaleLimit(width, height, name, enabled, style)
	assert(cached == new and fits == newFits, label .. ": the cached result retains its predicate")
	cases = cases + 1
end

local footprint, reads = Layouts.Footprint, {}
Layouts.Footprint = function(name, key)
	reads[key] = (reads[key] or 0) + 1
	return footprint(name, key)
end
Layouts.ScaleLimit(1922, 1080, "DPS", nil, "frames")
Layouts.Footprint = footprint
for _, element in ipairs(Layouts.ELEMENTS) do
	assert(reads[element.key] == 1, element.key .. ": hoist the footprint once per search, including Story and the search span")
end

local story, calls = Layouts.Story, 0
Layouts.Story = function(...)
	calls = calls + 1
	return story(...)
end
local _, fits = Layouts.ScaleLimit(1921, 1080, "DPS", nil, "frames")
fits(0.8)
local first = calls
fits(0.8)
assert(calls == first, "the exact Story tuple is memoised in this search")
fits(0.81)
assert(calls == first + 1, "a different root height must refresh the reusable Story cards")
Layouts.Story = story

for _, name in ipairs(Layouts.Names()) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		for _, screen in ipairs(screens) do
			Check(name, style, screen)
		end
		local enabled = Layouts.Enabled(name)
		enabled["actionbars.bar3"], enabled["groupframes.party"], enabled["groupframes.raid"] = true, true, true
		Check(name, style, screens[1], enabled)
		for key in pairs(enabled) do
			enabled[key] = false
		end
		Check(name, style, screens[3], enabled)
	end
end

-- Mutating a public copy must never change Story or a later search.
local before = Layouts.Story("DPS", 1080, true, "frames", 1920)
local copy = Layouts.Get("DPS")
copy["unitframes.targettarget"].x = 1e9
assert(Layouts.Get("DPS")["unitframes.targettarget"].x ~= 1e9,
	"keep Get copying every position: a caller must not edit the stored layout")
local after = Layouts.Story("DPS", 1080, true, "frames", 1920)
assert(after.quests.height == before.quests.height and after.guide.height == before.guide.height,
	"keep Get copying: caller edits must not change the stored Story layout")
assert(#env._errors == 0, "the identity fixture raised no addon errors")
print("scalelimit identity ok (" .. cases .. " exact doubles and predicates)")
