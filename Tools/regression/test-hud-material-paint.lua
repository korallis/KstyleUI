-- test-hud-material-paint.lua: the render step that paints card material against the resolved owner rect (Tools/render/scene.lua) on widget cases: it paints stubs whose raw size is nil, restores the owner's getters exactly, follows a resized owner and runs no layout.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local Lib = dofile("Tools/regression/hud_material_lib.lua")

local MATERIALS = { "Glass", "Flat", "Slate", "ForgedTicks", "ForgedBrackets" }
local SCREENS = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }

local function itemOf(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			return item
		end
	end
end

local function world(width, height, size)
	local env, K = W.New({ width = width, height = height, size = size, setup = function(e)
		e._materialChromes = {}
	end })
	local root = K.Scale.Root()
	local function frame(parent)
		return env.CreateFrame("Frame", nil, parent or root)
	end
	local w = { env = env, K = K, root = root }
	w.left = frame()
	w.left:SetSize(400, 300)
	w.left:SetPoint("TOPLEFT", root, "TOPLEFT", 100, -100)
	w.right = frame()
	w.right:SetSize(120, 90)
	w.right:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -60, 70)
	w.owners = {}
	local function card(name, setup)
		local owner = frame()
		setup(owner)
		local chrome = K.Widgets.Chrome(owner, { shape = "card" })
		local probe = owner:CreateTexture(nil, "BACKGROUND")
		probe:SetAllPoints(owner)
		probe:SetColorTexture(1, 1, 1, 1)
		w.owners[#w.owners + 1] = { name = name, owner = owner, chrome = chrome, probe = probe }
	end
	card("span", function(owner)
		owner:SetPoint("TOPLEFT", w.left, "TOPLEFT")
		owner:SetPoint("TOPRIGHT", w.left, "TOPRIGHT")
		owner:SetHeight(150)
	end)
	card("two frames", function(owner)
		owner:SetPoint("TOPLEFT", w.left, "BOTTOMLEFT", 20, -30)
		owner:SetPoint("BOTTOMRIGHT", w.right, "BOTTOMRIGHT")
	end)
	card("scaled", function(owner)
		owner:SetScale(1.3)
		owner:SetPoint("TOPLEFT", w.left, "TOPRIGHT", 40, 0)
		owner:SetPoint("BOTTOMRIGHT", w.right, "TOPLEFT", 0, 40)
	end)
	card("sized", function(owner)
		owner:SetSize(240, 160)
		owner:SetPoint("CENTER", root, "CENTER", -300, 120)
	end)
	return w
end

local function audit(w, material, scene)
	local cards = Lib.Cards(scene)
	assert(#cards.unowned == 0)
	assert(#cards == #w.owners, material .. " draws " .. #w.owners .. " cards, got " .. #cards)
	local _, physicalHeight = w.env.GetPhysicalScreenSize()
	local spec = w.K.Tokens.Material(material)
	for _, card in ipairs(cards) do
		Lib.AuditCard(card, material)
		for _, o in ipairs(w.owners) do
			if o.chrome == card.chrome then
				local want = itemOf(scene, o.probe).rect
				local span = card.drawn.materialFrame and { want[1], want[2], want[1] + want[3], want[2] + want[4] }
				if span then
					local got = { 1e9, 1e9, -1e9, -1e9 }
					for _, item in ipairs(card.drawn.materialFrame) do
						got = { math.min(got[1], item.rect[1]), math.min(got[2], item.rect[2]), math.max(got[3], item.rect[1] + item.rect[3]), math.max(got[4], item.rect[2] + item.rect[4]) }
					end
					-- The chrome grows its far corners to the next whole pixel (Widgets.Remainder), so the frame may end
					-- up to one physical pixel past an owner whose own size is fractional.
					for i = 1, 4 do
						assert(math.abs(got[i] - span[i]) <= 1080 / physicalHeight + 0.01, o.name .. " " .. material .. " forged frame is off the owner's resolved rect")
					end
				end
				local grain = card.drawn.grain and card.drawn.grain[1]
				if grain then
					local texels = grain.texCoord[2] * spec.texels
					assert(math.abs(texels / (grain.rect[3] * physicalHeight / 1080) - 1) < 0.002, o.name .. " " .. material .. " grain is not one physical pixel per texel")
					assert(math.abs(grain.texCoord[4] * spec.texels / (grain.rect[4] * physicalHeight / 1080) - 1) < 0.002)
				end
			end
		end
	end
end

local function untouched(w)
	for _, o in ipairs(w.owners) do
		assert(rawget(o.owner, "GetWidth") == nil and rawget(o.owner, "GetHeight") == nil, o.name .. " keeps no getter the render step set")
	end
end

for _, screen in ipairs(SCREENS) do
	for _, size in ipairs({ 0.6, 16 / 19, 1.5 }) do
		local w = world(screen[1], screen[2], size)
		assert(w.owners[1].owner:GetWidth() == nil and w.owners[2].owner:GetWidth() == nil and w.owners[3].owner:GetWidth() == nil, "the stub reports no raw width for the anchored cards: the premise of the render step")
		for _, material in ipairs(MATERIALS) do
			w.K.Store.Module("Widgets").cardMaterial = material
			w.K.Widgets.RestyleAll()
			local calls = 0
			for _, o in ipairs(w.owners) do
				for _, name in ipairs({ "Paint", "Restyle", "Layout", "OnSizeChanged" }) do
					local original = o.chrome[name]
					o.chrome[name] = function(...)
						calls = calls + 1
						return original(...)
					end
				end
			end
			local scene = Scene.Build(w.env, {})
			assert(calls == 0, "Scene.Build runs no layout, restyle or size handler for a chrome, got " .. calls .. " calls")
			for _, o in ipairs(w.owners) do
				o.chrome.Paint, o.chrome.Restyle, o.chrome.Layout, o.chrome.OnSizeChanged = nil, nil, nil, nil
			end
			local ok, err = pcall(audit, w, material, scene)
			assert(ok, screen[1] .. "x" .. screen[2] .. " size " .. size .. " " .. material .. ": " .. tostring(err))
			untouched(w)
			assert(w.owners[1].owner:GetWidth() == nil, "the stored size is still nil")
		end
		assert(#w.env._errors == 0)
	end
end

do
	local w = world(2383, 1540, 16 / 19)
	local spanOwner = w.owners[1]
	local custom = function()
		return 123
	end
	spanOwner.owner.GetWidth, spanOwner.owner.GetHeight = custom, custom
	Scene.Build(w.env, {})
	assert(rawget(spanOwner.owner, "GetWidth") == custom and rawget(spanOwner.owner, "GetHeight") == custom, "an owner's own getters come back as the same functions")
	assert(spanOwner.owner:GetWidth() == 123)
	spanOwner.owner.GetWidth, spanOwner.owner.GetHeight = nil, nil

	local boom = w.owners[2]
	boom.chrome.PaintMaterial = function(chrome)
		assert(chrome == boom.chrome and boom.owner:GetWidth() and boom.owner:GetHeight(), "paint sees the resolved size")
		error("paint failed")
	end
	spanOwner.owner.GetWidth = custom
	local ok, message = pcall(Scene.Build, w.env, {})
	assert(not ok and tostring(message):find("paint failed", 1, true), "an error in paint surfaces: " .. tostring(message))
	assert(rawget(boom.owner, "GetWidth") == nil and rawget(boom.owner, "GetHeight") == nil, "an error restores the owner's getters")
	assert(boom.owner:GetWidth() == nil, "and the owner reads the stub's size again")
	assert(rawget(spanOwner.owner, "GetWidth") == custom, "a card painted before the error keeps its own getter too")
	boom.chrome.PaintMaterial = nil
	spanOwner.owner.GetWidth = nil

	local material = "ForgedBrackets"
	w.K.Store.Module("Widgets").cardMaterial = material
	w.K.Widgets.RestyleAll()
	audit(w, material, Scene.Build(w.env, {}))
	local before = {}
	for _, card in ipairs(Lib.Cards(Scene.Build(w.env, {}))) do
		before[card.chrome] = card.rect
	end

	w.left:SetSize(700, 420)
	local resized = Lib.Cards(Scene.Build(w.env, {}))
	audit(w, material, Scene.Build(w.env, {}))
	for _, card in ipairs(resized) do
		local moved = 0
		for k = 1, 4 do
			moved = moved + (math.abs(card.rect[k] - before[card.chrome][k]) > 1 and 1 or 0)
		end
		local sized = card.chrome == w.owners[4].chrome
		assert((moved > 0) == not sized, "a card anchored to the resized frame is painted against its new rect, one sized on its own is not")
	end

	w.left:SetSize(8, 8)
	w.right:SetSize(8, 8)
	local small = Lib.Cards(Scene.Build(w.env, {}))
	for _, card in ipairs(small) do
		if card.rect[3] - card.rect[1] < 16 then
			assert(not card.drawn.materialFrame and not card.drawn.materialBrackets, "a card too small for its frame draws neither frame nor brackets")
		end
	end

	w.left:SetSize(400, 300)
	w.right:SetSize(120, 90)
	audit(w, material, Scene.Build(w.env, {}))

	for _, o in ipairs(w.owners) do
		o.owner:Hide()
	end
	local hidden = Lib.Cards(Scene.Build(w.env, {}))
	assert(#hidden == 0, "hidden owners draw no card")
end

print("ok test-hud-material-paint")
