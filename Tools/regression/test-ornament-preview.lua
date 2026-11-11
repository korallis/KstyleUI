-- test-ornament-preview.lua: ornamental outsets do not resize the original content in the Options preview.
local O = dofile("Tools/regression/options_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local function Scale(shown)
	local handle
	local env, K, ns = O.New({ before = function(e, core)
		core.Layout = nil
		core.Modules.Register(O.W.CoreEnv.Module("UnitFrames", { defaults = {} }))
		local schema = { { type = "header", label = "Frames" } }
		schema.preview = function(parent)
			local frame = e.CreateFrame("Frame", nil, parent)
			frame:SetAllPoints(parent)
			local content = frame:CreateTexture(nil, "ARTWORK")
			content:SetSize(180, 80)
			content:SetPoint("CENTER", frame, "CENTER")
			content:SetTexture(core.Tokens.Texture("barFlat"))
			local portrait = e.CreateFrame("Frame", nil, frame)
			local pixel = core.Scale.Pixel(1) / core.Widgets.ScaleFactor(portrait)
			portrait:SetPoint("RIGHT", content, "LEFT", 20 * pixel, 0)
			portrait:SetSize(39 * pixel, 39 * pixel)
			handle = core.Widgets.Ornament(portrait, "ring")
			handle.elite = true
			return frame
		end
		core.Options.Register("UnitFrames", schema)
	end })
	K.Store.Module("Widgets").cardMaterial = "ForgedBrackets"
	K.Store.Module("Widgets").ornaments = shown and "Full" or "Off"
	K.Options.Open("UnitFrames")
	env.RunTimers()
	for _ = 1, 60 do O.W.Tick(env, 1 / 60) end
	env.RunTimers()
	local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(handle.target)
	handle.target:SetSize(39 * pixel, 39 * pixel)
	handle:Restyle()
	local scene = Scene.Build(env)
	local painted = 0
	for _, item in ipairs(scene.items) do
		for i = 1, handle.used do
			if item.object == handle.textures[i] then painted = painted + 1 end
		end
	end
	assert(painted == (shown and 2 or 0), "the preview collects the actual Full ring and elite pendant, got " .. painted .. " used " .. handle.used)
	return ns.Window.Parts().preview.current:GetScale()
end

local off, full = Scale(false), Scale(true)
assert(off == full, "ornaments must not change the preview content scale: " .. tostring(off) .. " versus " .. tostring(full))
print("ok ornamental outsets do not refit the preview")
