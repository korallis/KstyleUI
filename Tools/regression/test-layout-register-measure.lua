-- test-layout-register-measure.lua: Layout.Register measures the frame it registers, and in the game that measure resolves the frame's rect and runs its OnSizeChanged scripts inside GetWidth, Layout's own size hook included. The hook must not place an element whose settings are not resolved yet: in the owner's v0.1.0 session it did, and groupframes.raid raised "bad argument #1 to 'SetScale'" (Layout.lua:505) and a skin element "attempt to index local 'f' (a nil value)" (Geometry.lua:38). Settings with no scale or anchor are refused without an error.
local W = dofile("Tools/regression/widget_env.lua")

-- Fresh(env, K, w, h) -> a frame on the root sized off the pixel grid and never measured, as Headers.lua's raid header is.
local function Fresh(env, K, w, h)
	local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
	frame:SetSize(w, h)
	return frame
end

local POSITION = { anchor = "BOTTOMLEFT", x = 40, y = 300 }

do
	local env, K = W.New({ width = 2383, height = 1540, uiScale = 768 / 1080 })
	local frame = Fresh(env, K, 0.999999, 0.999973)
	assert(rawget(frame, "_sizeUnseen"), "the stub keeps a size no script has seen for the frame's first measure")
	local ok, err = pcall(K.Layout.Register, frame, "groupframes.raid", POSITION, { label = "Raid frames", scalable = true })
	assert(ok, "registering a scalable element whose first measure runs Layout's size hook: " .. tostring(err))
	assert(frame:GetScale() == 1, "the element keeps its own scale, got " .. tostring(frame:GetScale()))
	local point, relative = frame:GetPoint(1)
	assert(point == "BOTTOMLEFT" and relative == K.Scale.Root(), "and is placed at its default anchor, got " .. tostring(point))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local env, K = W.New()
	local frame = Fresh(env, K, 120.3, 40.7)
	local ok, err = pcall(K.Layout.Register, frame, "skins.window", POSITION, { label = "A window" })
	assert(ok, "registering a fixed-size element whose first measure runs Layout's size hook: " .. tostring(err))
	assert(frame:GetPoint(1) == "BOTTOMLEFT", "the element is placed at its default anchor")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A later size change still snaps the element through the hook once its settings are resolved.
do
	local env, K = W.New()
	local frame = Fresh(env, K, 100, 40)
	K.Layout.Register(frame, "skins.grow", POSITION, { label = "Grows" })
	frame:SetSize(130.37, 52.11)
	local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(frame)
	local n = frame:GetWidth() / pixel
	assert(math.abs(n - math.floor(n + 0.5)) < 1e-6, "a resolved element snaps a new size to whole pixels, got " .. tostring(frame:GetWidth()))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Settings that lost their scale or anchor are skipped without an error.
do
	local env, K = W.New()
	local frame = Fresh(env, K, 100, 40)
	K.Layout.Register(frame, "skins.broken", POSITION, { label = "Broken", scalable = true })
	local el = K.Layout.Element("skins.broken")
	el.settings.scale, el.settings.anchor = 0 / 0, "NOWHERE"
	local ok, err = pcall(frame.SetSize, frame, 101.37, 40)
	assert(ok, "a size change with settings that lost their values: " .. tostring(err))
	el.settings.scale, el.settings.anchor = nil, nil
	ok, err = pcall(frame.SetSize, frame, 103.37, 40)
	assert(ok, "and with no values at all: " .. tostring(err))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("test-layout-register-measure: Register's first measure never places an unresolved element, and missing values never throw")
