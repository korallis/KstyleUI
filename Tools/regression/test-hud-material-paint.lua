-- test-hud-material-paint.lua: widget cards render (Tools/render/scene.lua) in the Medallions steel against the resolved owner rect: stubs whose raw size is nil, getters left untouched, a resized owner followed and no layout run.
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local Lib = dofile("Tools/regression/hud_material_lib.lua")

local SCREENS = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }

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
		w.owners[#w.owners + 1] = { name = name, owner = owner, chrome = chrome }
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
	for _, owner in ipairs(w.owners) do owner.chrome:DrawSlices() end
	return w
end

local function audit(w, scene)
	local cards = Lib.Cards(scene)
	assert(#cards.unowned == 0)
	assert(#cards == #w.owners, "the steel draws " .. #w.owners .. " cards, got " .. #cards)
	for _, card in ipairs(cards) do
		Lib.AuditCard(card)
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
		for _, owner in ipairs(w.owners) do owner.chrome:DrawSlices() end
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
		local ok, err = pcall(audit, w, scene)
		assert(ok, screen[1] .. "x" .. screen[2] .. " size " .. size .. ": " .. tostring(err))
		untouched(w)
		assert(w.owners[1].owner:GetWidth() == nil, "the stored size is still nil")
		assert(#w.env._errors == 0)
	end
end

do
	local w = world(2383, 1540, 16 / 19)
	audit(w, Scene.Build(w.env, {}))
	local before = {}
	for _, card in ipairs(Lib.Cards(Scene.Build(w.env, {}))) do
		before[card.chrome] = card.rect
	end

	w.left:SetSize(700, 420)
	local resized = Lib.Cards(Scene.Build(w.env, {}))
	audit(w, Scene.Build(w.env, {}))
	for _, card in ipairs(resized) do
		local moved = 0
		for k = 1, 4 do
			moved = moved + (math.abs(card.rect[k] - before[card.chrome][k]) > 1 and 1 or 0)
		end
		local sized = card.chrome == w.owners[4].chrome
		assert((moved > 0) == not sized, "a card anchored to the resized frame is drawn at its new rect, one sized on its own is not")
	end

	for _, o in ipairs(w.owners) do
		o.owner:Hide()
	end
	local hidden = Lib.Cards(Scene.Build(w.env, {}))
	assert(#hidden == 0, "hidden owners draw no card")
end

print("ok test-hud-material-paint")
