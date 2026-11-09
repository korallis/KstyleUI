-- test-options-preview-fit.lua: the settings window's preview host gives each module preview a holder of known size, so a preview that sizes from its parent fits the pane; a sized preview is centred and scaled down to fit; and the host refits when the window changes size.
local O = dofile("Tools/regression/options_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local W = O.W
local Module = W.CoreEnv.Module

local FALLBACK = 400
local WIDE = 360
local TALL = 300
local SLACK = 0.5

local builds = {}

local env, K, ns = O.New({
	before = function(env, K)
		K.Layout = nil
		-- A preview that sizes a strip from its parent's width, as the unit frame, group frame and cooldown
		-- previews do, and falls back to a width wider than the pane when the parent has none.
		K.Modules.Register(Module("UnitFrames", { defaults = { width = 220 } }))
		local frames = {
			{ type = "header", label = "Frames" },
			{ type = "slider", key = "width", label = "Width", help = "Frame width in units.", min = 100, max = 400, step = 1 },
		}
		frames.preview = function(parent)
			local frame = env.CreateFrame("Frame", nil, parent)
			frame:SetAllPoints(parent)
			frame.strip = env.CreateFrame("Frame", nil, frame)
			frame.strip:SetPoint("TOP", frame, "TOP", 0, -10)
			frame.strip.fill = frame.strip:CreateTexture(nil, "ARTWORK")
			frame.strip.fill:SetAllPoints(frame.strip)
			frame.strip.fill:SetColorTexture(1, 0, 0, 1)
			frame.Refresh = function(self)
				local room = self:GetWidth()
				builds.rooms = builds.rooms or {}
				builds.rooms[#builds.rooms + 1] = room
				local width = type(room) == "number" and room > 0 and room or FALLBACK
				self.strip:SetSize(width, 30)
			end
			frame:Refresh()
			return frame
		end
		K.Options.Register("UnitFrames", frames)
		-- A preview that returns a frame of its own size and no anchors, wider and taller than the pane holds.
		K.Modules.Register(Module("Cooldowns", { defaults = { size = 38 } }))
		local cooldowns = {
			{ type = "header", label = "Cooldowns" },
			{ type = "slider", key = "size", label = "Size", help = "Socket size in units.", min = 20, max = 60, step = 1 },
		}
		cooldowns.preview = function(parent)
			local frame = env.CreateFrame("Frame", nil, parent)
			frame:SetSize(WIDE, TALL)
			frame.fill = frame:CreateTexture(nil, "ARTWORK")
			frame.fill:SetAllPoints(frame)
			frame.fill:SetColorTexture(0, 1, 0, 1)
			builds.cooldowns = (builds.cooldowns or 0) + 1
			return frame
		end
		K.Options.Register("Cooldowns", cooldowns)
	end,
})

local function settle(e)
	e.RunTimers()
	W.Settle(e)
	e.RunTimers()
end

-- Scene.Build measures every font string's natural size, which the caption's anchors need before the rects below resolve.
local function rect(object)
	Scene.Build(env, {})
	local x, y, w, h = Scene.Rect(env, object)
	assert(x, "the rect of " .. tostring(object._name or object) .. " resolves")
	return { left = x, right = x + w, top = y, bottom = y + h }
end

local function inside(inner, outer, what)
	assert(inner.left >= outer.left - SLACK and inner.right <= outer.right + SLACK and inner.top >= outer.top - SLACK and inner.bottom <= outer.bottom + SLACK,
		string.format("%s lies inside the pane: %.1f..%.1f x %.1f..%.1f against %.1f..%.1f x %.1f..%.1f", what, inner.left, inner.right, inner.top, inner.bottom, outer.left, outer.right, outer.top, outer.bottom))
end

-- The holder has a known size, so a preview that sizes from its parent fits ----------------------------

K.Options.Open("UnitFrames")
settle(env)
local pane = ns.Window.Parts().preview
local holder = pane.holder
local holderW, holderH = holder:GetWidth(), holder:GetHeight()
assert(type(holderW) == "number" and holderW > 0 and type(holderH) == "number" and holderH > 0, "the preview holder has an explicit size: " .. tostring(holderW) .. " x " .. tostring(holderH))
local paneW, paneH = pane:GetWidth(), pane:GetHeight()
assert(holderW < paneW and holderH < paneH, "the holder sits inside the pane's inset")
local current = pane.current
assert(current and current.strip, "the UnitFrames preview is current")
assert(builds.rooms and builds.rooms[#builds.rooms] == holderW, "the preview read the holder's width, not nil: " .. tostring(builds.rooms and builds.rooms[#builds.rooms]))
inside(rect(current.strip), rect(pane), "the strip sized from the holder")
assert(rect(current.strip).right - rect(current.strip).left < FALLBACK, "the strip did not fall back to its full width")

-- A sized, unanchored preview is centred in the holder and scaled down to fit it -----------------------

K.Options.Open("Cooldowns")
settle(env)
current = pane.current
assert(current and current.fill and builds.cooldowns == 1, "the Cooldowns preview is current")
local scale = current:GetScale()
assert(type(scale) == "number" and scale < 1 and scale > 0, "a preview wider than the holder is scaled down: " .. tostring(scale))
assert(math.abs(scale - math.min(holderW / WIDE, holderH / TALL)) < 0.001, "the scale fits both the width and the height: " .. tostring(scale))
local shown = rect(current)
inside(shown, rect(pane), "the scaled preview")
local hold = rect(holder)
local dx = (shown.left + shown.right) / 2 - (hold.left + hold.right) / 2
local dy = (shown.top + shown.bottom) / 2 - (hold.top + hold.bottom) / 2
assert(math.abs(dx) < 1 and math.abs(dy) < 1, string.format("the preview is centred in the holder (off by %.1f, %.1f)", dx, dy))

-- The host refits when the window changes size -----------------------------------------------------------

local win = ns.Window.Parts().preview:GetParent()
local w, h = win:GetSize()
local SHRINK = 320
win:SetSize(w, h - SHRINK)
local sizeChanged = win._scripts.OnSizeChanged
assert(type(sizeChanged) == "function", "the window relayouts on size change")
sizeChanged(win, w, h - SHRINK)
settle(env)
assert(holder:GetHeight() < holderH and holder:GetHeight() < TALL * scale, "the holder shrank with the window below the preview's scaled height: " .. tostring(holder:GetHeight()))
local after = current:GetScale()
assert(after < scale, "the sized preview was refit to the shorter holder: " .. tostring(after) .. " after " .. tostring(scale))
inside(rect(current), rect(pane), "the refit preview")

K.Options.Open("UnitFrames")
settle(env)
current = pane.current
assert(builds.rooms[#builds.rooms] == holder:GetWidth(), "the parent-sized preview refreshed against the holder's size")
inside(rect(current.strip), rect(pane), "the strip after the resize")

print("options preview fit ok")
