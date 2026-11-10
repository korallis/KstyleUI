-- test-tooltips-preview-fit.lua: paired preview labels fit their applied fonts on physical-pixel steps without changing the tooltip settings or sample box.
local T = dofile("Tools/regression/tooltips_env.lua")
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene

local function New(width, height, locale, custom, set)
	Common.DEFAULT_SCREEN = { width = width, height = height, uiScale = 768 / 1080 }
	local env, K, ns = T.New({ setup = function(game)
		Common.ForceScreen(game)
		game.GetLocale = function() return locale end
	end })
	assert(K.Theme.SetTypeSet(set or "Folio"), "the requested type set exists")
	if custom then
		K.Options.Write("Tooltips", "followFont", false)
		K.Options.Write("Tooltips", "body.font", "Interface\\AddOns\\KstyleUI\\Media\\Fonts\\Inter-SemiBold.ttf")
		K.Options.Write("Tooltips", "body.size", 20)
		K.Options.Write("Tooltips", "body.outline", "THICKOUTLINE")
	end
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(260, 430)
	local frame = ns.Preview.Build(parent)
	return env, K, ns, frame
end

local function Check(width, height, locale, custom, set)
	local env, K, ns, frame = New(width, height, locale, custom, set)
	local W = K.Widgets
	local sample = frame.item
	local row = sample.rows[5]
	local path, size, flags = row.left:GetFont()
	local rightPath, rightSize, rightFlags = row.right:GetFont()
	local configuredPath, configuredSize, configuredFlags = ns.Style.FontSpec("body")
	local full = W.FontSize(row.left, configuredSize)
	local pixel = W.FontSize(row.left, 0)
	local floor = W.FontSize(row.left, 8 * K.Theme.FontScale())
	local pad = W.Snap(sample, K.Tokens.Size("gapMedium"))
	local gap = W.Snap(sample, K.Tokens.Size("gapSmall"))
	local available = sample:GetWidth() - sample.indent - 2 * pad
	local need = W.TextWidth(row.left) + W.TextWidth(row.right) + gap
	assert(need <= available + 1e-6, locale .. " " .. height .. ": paired labels need " .. need .. ", have " .. available)
	assert(size >= floor and size <= full, "the preview stays within the configured size and the module's snapped eight-unit floor")
	assert(T.Near(size / pixel, math.floor(size / pixel + 0.5)), "the fitted size is a physical-pixel step")
	assert(T.Near(size, rightSize), "the two labels shrink together")
	assert(path == configuredPath and rightPath == configuredPath and flags == configuredFlags and rightFlags == configuredFlags, "fitting preserves the applied custom faces and outlines")
	if size < full then
		local nextSize = size + pixel
		local nextNeed = Scene.TextWidth(row.left:GetText(), nextSize, path) + Scene.TextWidth(row.right:GetText(), nextSize, rightPath) + gap
		assert(nextNeed > available, "the next snapped physical size does not fit, so this is the largest fitting step")
	else
		assert(not custom and locale == "enUS" or set == "Lumen", "short default and original-face samples keep their configured size")
	end
	assert(row.left:GetText() == K.L["142 - 198 Damage"] and row.right:GetText() == K.L["Speed 1.80"], "neither fixed label is rewritten or truncated")
	assert(T.Near(sample:GetWidth(), W.Snap(sample, 190 + sample.indent)), "the sample box keeps its original width")
	local leftAnchor, _, _, x = row.left:GetPoint(1)
	local leftRightAnchor = row.left:GetPoint(2)
	local rightAnchor = row.right:GetPoint(1)
	assert(leftAnchor == "TOPLEFT" and T.Near(x, pad + sample.indent) and leftRightAnchor == "RIGHT" and rightAnchor == "TOPRIGHT", "the existing left and right anchors do not change")
	local _, _, _, _, nextY = sample.rows[6].left:GetPoint(1)
	local _, _, _, _, rowY = row.left:GetPoint(1)
	assert(T.Near(rowY - nextY, full * 1.2 + W.Snap(sample, 2)), "the following row keeps its original pitch while the paired ink fits inside it")
	assert(ns.Settings.Get("body.size") == (custom and 20 or 11), "fitting never writes the global/module font setting")
	local _, singleSize = sample.rows[3].left:GetFont()
	assert(T.Near(singleSize, full), "single-column sample lines are not fitted")
	frame:Refresh()
	assert(T.Near(select(2, row.left:GetFont()), size), "refresh is stable and does not repeatedly shrink")
	if custom then
		K.Options.Write("Tooltips", "body.size", 8)
		frame:Refresh()
		assert(T.Near(select(2, row.left:GetFont()), floor), "the actual eight-unit setting stays at its snapped floor")
		K.Options.Write("Tooltips", "body.size", 11)
		K.Options.Write("Tooltips", "followFont", true)
		frame:Refresh()
		assert(row.left:GetFont() == K.Tokens.Font("body"), "returning to the inherited face reapplies it before fitting")
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end

Check(1280, 720, "frFR")
Check(1366, 768, "frFR")
Check(1280, 720, "enUS")
Check(1920, 1080, "enUS")
Check(1280, 720, "frFR", false, "Lumen")
Check(1280, 720, "frFR", true)

do
	local env, K, ns, frame = New(1280, 720, "frFR")
	local row = frame.item.rows[5]
	local full = K.Widgets.FontSize(row.left, select(2, ns.Style.FontSpec("body")))
	local saved = row.right.GetUnboundedStringWidth
	for _, unknown in ipairs({ function() return nil end, function() return env.Secret(200) end, function() return 0 / 0 end, function() return math.huge end }) do
		row.right.GetUnboundedStringWidth = unknown
		local ok, err = pcall(frame.Refresh, frame)
		assert(ok, "unavailable or secret metrics do not raise: " .. tostring(err))
		assert(T.Near(select(2, row.left:GetFont()), full), "unknown metrics never drive a guessed smaller size")
	end
	row.right.GetUnboundedStringWidth = saved
	frame:Refresh()
	assert(select(2, row.left:GetFont()) < full, "known metrics can fit again after an unknown measurement")
	local measured = 0
	row.right.GetUnboundedStringWidth = function(self)
		measured = measured + 1
		if measured == 1 then return saved(self) end
		return nil
	end
	frame:Refresh()
	assert(T.Near(select(2, row.left:GetFont()), full) and T.Near(select(2, row.right:GetFont()), full), "a measurement lost during fitting restores both configured fonts")
	row.right.GetUnboundedStringWidth = saved
	local setFont = row.right.SetFont
	row.right.SetFont = function(self, path, size, flags)
		if size < full then return false end
		return setFont(self, path, size, flags)
	end
	frame:Refresh()
	assert(T.Near(select(2, row.left:GetFont()), full) and T.Near(select(2, row.right:GetFont()), full), "a rejected fitted font restores both original sizes")
	row.right.SetFont = setFont
	K.Options.Write("Tooltips", "body.size", 8)
	K.Theme.SetFontScale(1.4)
	frame:Refresh()
	local floor = K.Widgets.FontSize(row.left, 8 * K.Theme.FontScale())
	assert(T.Near(select(2, row.left:GetFont()), floor), "an enlarged minimum font is never shrunk below the module's scaled floor even if the labels cannot fit")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("test-tooltips-preview-fit: ok")
