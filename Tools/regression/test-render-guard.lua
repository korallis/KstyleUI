-- test-render-guard.lua: Tools/render/guard.lua lists texts the page would truncate and content past its glass card, and the allowlist and modes gate a render.
local Stubs = dofile("Tools/regression/stubs/wow.lua")
local Scene = dofile("Tools/render/scene.lua")
local Guard = dofile("Tools/render/guard.lua")

local TEX = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\"

local env = Stubs.NewEnv({ width = 1920, height = 1080 })
local UIParent = env.UIParent

local function glass(frame)
	for _, name in ipairs({ "LumenShadow", "LumenShape", "LumenFrost", "LumenRim" }) do
		local t = frame:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(TEX .. name .. ".png")
		if name == "LumenShadow" then
			t:SetPoint("TOPLEFT", frame, "TOPLEFT", -12, 12)
			t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 12, -12)
		else
			t:SetAllPoints(frame)
		end
	end
end

local function text(parent, value, width, wrap)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont("Interface\\AddOns\\KstyleUI\\Media\\Fonts\\SourceSans3-Regular.ttf", 14, "")
	fs:SetWordWrap(wrap ~= false)
	fs:SetSize(width, 16)
	fs:SetText(value)
	return fs
end

local function icon(parent, x, y)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(20, 20)
	t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	t:SetColorTexture(1, 1, 1, 1)
	return t
end

-- A window card: its own glass, a title that fits, a label too narrow for its text, an icon inside and one hung
-- 40 units off its right edge, and a soft shadow that bleeds past the glass by design.
local window = env.CreateFrame("Frame", "GuardWindow", UIParent)
window:SetSize(300, 200)
window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
glass(window)
text(window, "Fits", 200, false):SetPoint("TOPLEFT", window, "TOPLEFT", 10, -10)
text(window, "A label far too long for its narrow rect", 40, false):SetPoint("TOPLEFT", window, "TOPLEFT", 10, -40)
icon(window, 10, -80)
local column = env.CreateFrame("Frame", nil, window)
column:SetSize(20, 20)
column:SetPoint("TOPLEFT", window, "TOPRIGHT", 20, -80)
window.column = column
icon(column, 0, 0)

-- A proc glow on a button at the window's edge bleeds past the glass by design.
local button = env.CreateFrame("Frame", nil, window)
button:SetSize(20, 20)
button:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, -2)
local glow = button:CreateTexture(nil, "OVERLAY")
glow:SetTexture(TEX .. "Glow.png")
glow:SetPoint("TOPLEFT", button, "TOPLEFT", -10, 10)
glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 10, -10)

-- A tab card hung off the window's edge: its own glass, inside the window's content, outside the window's glass.
local tabs = env.CreateFrame("Frame", nil, window)
tabs:SetSize(30, 60)
tabs:SetPoint("TOPLEFT", window, "TOPRIGHT", 30, -120)
window.tabs = tabs
glass(tabs)

-- A popout list: its own glass beside the window, its tiles hung under the window in the frame tree, as the
-- Blessings card's full list is. The tiles sit wholly on the popout's glass, so they are not a spill.
local popout = env.CreateFrame("Frame", nil, UIParent)
popout:SetSize(120, 120)
popout:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 500, -100)
glass(popout)
local tile = env.CreateFrame("Frame", nil, window)
tile:SetSize(20, 20)
tile:SetPoint("TOPLEFT", popout, "TOPLEFT", 10, -10)
icon(tile, 0, 0)

-- A backdrop (glass with no text or frames of its own) clothing a content frame: the content's line that runs past
-- the backdrop's glass is a spill. A second backdrop on a wide holder does not make the holder's far children its
-- content.
local content = env.CreateFrame("Frame", nil, UIParent)
content:SetSize(200, 100)
content:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -400)
local backdrop = env.CreateFrame("Frame", nil, content)
backdrop:SetAllPoints(content)
glass(backdrop)
text(content, "Spills past the backdrop", 200, true):SetPoint("TOPLEFT", content, "TOPLEFT", 60, -60)
local holder = env.CreateFrame("Frame", nil, UIParent)
holder:SetSize(1200, 600)
holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -10)
local slot = env.CreateFrame("Frame", nil, holder)
slot:SetSize(100, 40)
slot:SetPoint("TOPLEFT", holder, "TOPLEFT", 900, -300)
glass(slot)
icon(holder, 1100, -500)

-- A sub-panel card inside the window whose label spills past the sub-panel onto the window's glass: the window is
-- the panel's own ancestor, so its glass excuses nothing (codex review). And a card larger than the card that holds
-- it: containment does not depend on which card is bigger.
local panel = env.CreateFrame("Frame", "GuardPanel", window)
panel:SetSize(80, 40)
panel:SetPoint("TOPLEFT", window, "TOPLEFT", 150, -40)
glass(panel)
text(panel, "Spills onto the window", 140, true):SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
local small = env.CreateFrame("Frame", "GuardSmall", UIParent)
small:SetSize(60, 60)
small:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 700, -400)
glass(small)
local big = env.CreateFrame("Frame", nil, small)
big:SetSize(120, 120)
big:SetPoint("TOPLEFT", small, "TOPLEFT", 0, 0)
small.big = big
glass(big)
text(big, "Big card", 80, false):SetPoint("TOPLEFT", big, "TOPLEFT", 10, -10)

-- An arched card (the minimap's lens card): a lens disc on the card frame itself is part of its glass, so the lens
-- inside the arch is on the card.
local arch = env.CreateFrame("Frame", "GuardArch", UIParent)
arch:SetSize(100, 60)
arch:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 900, -300)
glass(arch)
local dome = arch:CreateTexture(nil, "BORDER")
dome:SetTexture(TEX .. "LensMask.png")
dome:SetPoint("BOTTOMLEFT", arch, "TOPLEFT", 0, 0)
dome:SetSize(100, 50)
local lens = env.CreateFrame("Frame", nil, arch)
lens:SetSize(80, 80)
lens:SetPoint("BOTTOM", arch, "BOTTOM", 0, 10)
arch.lens = lens
icon(lens, 0, 0):SetSize(80, 80)

local scene = Scene.Build(env, {})
local findings = Guard.Check(scene)
local by = {}
for _, f in ipairs(findings) do
	by[f.kind .. "|" .. f.subject] = f
end

assert(not by["ellipsis|Fits"], "a text that fits its rect is not truncated")
local cut = by["ellipsis|A label far too long for its narrow rect"]
assert(cut and cut.detail:find("needs", 1, true), "a text that may not wrap and runs past its rect ends in ...")
assert(not by["ellipsis|Spills past the backdrop"], "a wrapping text is never an ellipsis")

local outside = {}
for _, f in ipairs(findings) do
	if f.kind == "outside" then
		outside[#outside + 1] = f.subject
	end
end
local function has(prefix)
	for _, subject in ipairs(outside) do
		if subject:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end
assert(has("GuardWindow.column"), "an icon hung 20 units off the window's edge is outside its card: " .. table.concat(outside, "; "))
assert(has("GuardWindow.tabs glass"), "a tab card hung off the window's edge is outside the window's glass")
assert(has("Spills past the backdrop"), "a line that runs past the backdrop clothing its frame is outside")
assert(not has("GuardWindow.?"), "the shadow, the glass and the icon inside stay quiet")
assert(not has("GuardArch"), "a lens under its card's arch is on the card's glass")
for _, subject in ipairs(outside) do
	assert(not subject:find("LumenShadow", 1, true) and not subject:find("Glow", 1, true), "a shadow or a glow bleeds by design: " .. subject)
end
assert(has("Spills onto the window"), "a label that spills out of its sub-panel onto the window's glass is outside")
assert(has("GuardSmall.big glass"), "a card larger than the card that holds it is checked against it")
assert(#outside == 5, "only the five spills are listed, not the popout's tiles or the wide holder's children: " .. table.concat(outside, "; "))

-- The allowlist: an owner scope, a scene glob, a kind and a subject prefix ("=" for the whole subject).
local path = os.tmpname()
local handle = assert(io.open(path, "wb"))
handle:write("# a comment\n\n")
handle:write("R4b\tgallery_window\toutside\tGuardWindow.column\tthe column is R4b's\n")
handle:write("design\t*\toutside\t=Spills past\tdeliberate\n")
handle:write("R2\tgallery_window\tellipsis\tGone\tfixed already\n")
handle:write("R2\tgallery_*\tellipsis\tAlso gone\tglob lines span scenes\n")
handle:close()
local allow = Guard.LoadAllow(path)
assert(#allow == 4, "comments and blank lines are skipped")
assert(Guard.Covers("=N", "N") and not Guard.Covers("=N", "Night"), "= matches the whole subject")
assert(Guard.Covers("Step 3", "Step 34") and not Guard.Covers("Step 3", "A Step 34"), "a subject matches from its start")

local fresh, allowed, stale = Guard.Sort(findings, allow, "gallery_window")
assert(#allowed == 1 and allowed[1].entry.owner == "R4b", "the R4b line covers the column")
assert(#fresh == 5, "the ellipsis, the tab card, the sub-panel spill, the big card and the backdrop spill stay fresh (=Spills past is not the whole subject)")
assert(#stale == 1 and stale[1].match == "Gone", "a line naming this scene that matched nothing is stale; a glob line is not")

local lines, fails = Guard.Lines(fresh, allowed, stale, "report")
local _
assert(not fails and #lines == #fresh + #allowed + #stale, "report lists every finding and the stale line, and never fails")
_, fails = Guard.Lines({}, allowed, stale, "default")
assert(not fails, "the default mode passes allowlisted findings and stale lines")
_, fails = Guard.Lines(fresh, allowed, {}, "default")
assert(fails, "the default mode fails a fresh finding")
_, fails = Guard.Lines({}, allowed, stale, "strict")
assert(fails, "strict fails a stale line, so a fixed defect leaves the list")
_, fails = Guard.Lines({}, allowed, {}, "strict")
assert(not fails, "strict passes allowlisted findings, so other scopes' known defects do not block a publish")

-- A malformed line or an unknown owner is an error, so a typo cannot allow everything.
handle = assert(io.open(path, "wb"))
handle:write("R9\tgallery_window\toutside\tX\tno such scope\n")
handle:close()
assert(not pcall(Guard.LoadAllow, path), "an unknown owner scope is an error")
handle = assert(io.open(path, "wb"))
handle:write("R2 gallery_window outside X spaces\n")
handle:close()
assert(not pcall(Guard.LoadAllow, path), "a line that is not tab-separated is an error")

-- The ellipsis slack is the page's half pixel at the density the page draws (shoot.sh --ppu, RENDER_PPU).
do
	local font = { size = 14, path = "Interface\\AddOns\\KstyleUI\\Media\\Fonts\\SourceSans3-Regular.ttf" }
	local need = Scene.TextWidth("HELLO", font.size, font.path)
	local tight = { items = { { kind = "text", text = "HELLO", rect = { 0, 0, need - 0.4, 20 }, font = font, wordWrap = false } } }
	local ppu = Guard.ppu
	Guard.ppu = 1
	assert(#Guard.Check(tight) == 0, "at 1 px per unit a 0.4-unit excess is inside the page's half pixel")
	Guard.ppu = 2
	assert(#Guard.Check(tight) == 1, "at 2 px per unit it is not")
	Guard.ppu = ppu
end

-- The raw sidecar: the scene step's findings and the page's truncations, deduplicated by kind and subject.
Guard.WriteRaw(findings, path)
handle = assert(io.open(path, "ab"))
handle:write("ellipsis\tA label far too long for its narrow rect\tthe page truncates it\t\n")
handle:write("ellipsis\tQUESTS\tthe page truncates it: needs 65.4 units, has 58.9\t\n")
handle:close()
local raw = Guard.ReadRaw(path)
assert(#raw == #findings + 1, "the page's truncation of a text the scene step listed is one finding, a new one is added")
os.remove(path)

-- The repository's allowlist parses, and every line names a scope.
for _, entry in ipairs(Guard.LoadAllow()) do
	assert(Guard.OWNERS[entry.owner], "an owner for line " .. entry.line)
end

print("ok - render guard: ellipsis, spills past a card, tab cards, popouts, backdrops, allowlist and modes")
