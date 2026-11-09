-- test-groupframes-preview-fit.lua: the options live preview stacks the party block, the raid block and the click casting panel, each with a measured height, inside the 280-unit pane, with nothing overlapping the click casting panel; it fits again when the pane resizes, and threat draws as an edge, not a wash over the row.
local G = dofile("Tools/regression/group_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local PANE_W = 280

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function inside(r, box, what)
	assert(r[1] >= box[1] - 0.01 and r[2] >= box[2] - 0.01 and r[1] + r[3] <= box[1] + box[3] + 0.01 and r[2] + r[4] <= box[2] + box[4] + 0.01,
		what .. string.format(" [%.1f %.1f %.1f %.1f] inside [%.1f %.1f %.1f %.1f]", r[1], r[2], r[3], r[4], box[1], box[2], box[3], box[4]))
end

local function describe(r)
	return string.format("[%.1f %.1f %.1f %.1f]", r[1], r[2], r[3], r[4])
end

-- Resize(frame, w, h): the size changes and OnSizeChanged runs, as the engine does once a frame's anchors resolve.
local function Resize(frame, w, h)
	frame:SetSize(w, h)
	local script = frame:GetScript("OnSizeChanged")
	if script then
		script(frame, w, h)
	end
end

-- Every drawn item under the preview, from the renderer.
local function Drawn(scene, root)
	local out = {}
	for _, item in ipairs(scene.items) do
		local object = item.object
		local owner = object
		while owner and owner ~= root do
			owner = owner.GetParent and owner:GetParent() or nil
		end
		if owner == root then
			out[#out + 1] = item
		end
	end
	return out
end

local function Under(object, root)
	while object do
		if object == root then
			return true
		end
		object = object.GetParent and object:GetParent() or nil
	end
	return false
end

local env, K = G.New()
local root = K.Scale.Root()
-- The options pane holder is anchored by two points, so its size is unknown when the preview is built; the game
-- resolves it a frame later and runs OnSizeChanged.
local pane = env.CreateFrame("Frame", nil, root)
pane:SetPoint("TOPLEFT", root, "TOPLEFT", 40, -40)
local preview = K.Options.Preview("GroupFrames")(pane)

for _, height in ipairs({ 720, 560 }) do
	-- The preview fills the pane (SetAllPoints), so the engine resizes both and runs the preview's OnSizeChanged.
	Resize(pane, PANE_W, height)
	local onSize = preview:GetScript("OnSizeChanged")
	assert(onSize, "the preview refits when its size resolves or changes")
	onSize(preview, PANE_W, height)
	local what = "pane " .. PANE_W .. " by " .. height
	local box = { Scene.Rect(env, pane) }
	local party, raid, click = { Scene.Rect(env, preview.party) }, { Scene.Rect(env, preview.raid) }, { Scene.Rect(env, preview.clickCast) }
	local scale = preview.canvas:GetScale()
	assert(scale > 0 and scale <= 1, what .. ": the preview scales down to fit, got " .. scale)
	inside(party, box, what .. ": the party block")
	inside(raid, box, what .. ": the raid block")
	inside(click, box, what .. ": the click casting panel")
	assert(not intersects(party, raid), what .. ": the party and raid blocks stack")
	assert(not intersects(raid, click), what .. ": the raid block " .. describe(raid) .. " stays clear of the click casting panel " .. describe(click))
	assert(not intersects(party, click), what .. ": and so does the party block")
	assert(raid[2] >= party[2] + party[4] - 0.01 and click[2] >= raid[2] + raid[4] - 0.01, what .. ": party, then raid, then click casting, top to bottom")
	-- Every drawn sample item lies inside the pane and off the click casting panel. Drop shadows and the threat halo
	-- bleed past a tile's edge by design, as the render guard treats them; they still stay off the click casting panel.
	local scene = Scene.Build(env)
	-- Opus R5 #1, Fable R5 #5: four raid tiles at true scale, never scaled down, every sample name whole.
	eq(#preview.raidFrames, 4, what .. ": four raid tiles")
	eq(preview.raidCanvas:GetScale(), 1, what .. ": the raid tiles keep true scale")
	for _, f in ipairs(preview.raidFrames) do
		eq(f.name:GetText(), f.sample.name, what .. ": the raid sample " .. f.sample.name .. " is whole")
	end
	local drawn = Drawn(scene, preview.canvas)
	for _, item in ipairs(Drawn(scene, preview.raidCanvas)) do
		drawn[#drawn + 1] = item
	end
	for _, item in ipairs(drawn) do
		local halo = type(item.file) == "string" and item.file:find("Shadow%.png$") ~= nil
		if not halo then
			inside(item.rect, box, what .. ": " .. tostring(item.kind) .. " " .. tostring(item.text or item.texture or ""))
		end
		assert(not intersects(item.rect, click), what .. ": " .. tostring(item.kind) .. " " .. tostring(item.text or item.texture or "") .. " " .. describe(item.rect) .. " stays off the click casting panel")
	end
	-- Opus R4 #1: the tank's threat is an edge round the row, never a wash across it.
	local tank = preview.partyFrames[1]
	assert(tank.threat:IsShown(), what .. ": the sample tank shows threat")
	local row = { Scene.Rect(env, tank) }
	local cx, cy = row[1] + row[3] / 2, row[2] + row[4] / 2
	for _, item in ipairs(scene.items) do
		if Under(item.object, tank.threat) then
			local r = item.rect
			local covers = r[1] < cx and cx < r[1] + r[3] and r[2] < cy and cy < r[2] + r[4]
			assert(not covers, what .. ": the threat " .. tostring(item.kind) .. " " .. describe(r) .. " leaves the row's middle clear")
		end
	end
	-- Muse R4 D9: the sample rows use no skull marker, which reads as the dead state.
	for _, f in ipairs(preview.partyFrames) do
		assert(f.sample.marker ~= 8, "the preview's sample " .. f.sample.name .. " carries no skull")
	end
end
eq(#env._errors, 0, tostring(env._errors[1]))

print("groupframes preview fit ok")
