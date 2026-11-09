-- test-options-preview-fill.lua: the settings window's preview host scales a preview up as well as down, so a sized
-- preview smaller than the pane and an unsized preview whose drawn content is smaller than the pane both grow toward
-- the pane's width, capped at 1.25, and stay inside it; content that already fills the pane keeps scale 1 (round 5:
-- Opus #4, Fable #5: the Unit Frames preview filled a fifth of its pane).
local O = dofile("Tools/regression/options_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local W = O.W
local Module = W.CoreEnv.Module

local SMALL_W, SMALL_H = 100, 60
local NEAR = 1.1
local STRIP_W, STRIP_H = 160, 40
local GLOW_PAD = 60
local SELF_FIT = 0.8
local SLACK = 0.5
local EPS = 0.001

local refreshes = {}

local env, K, ns = O.New({
	before = function(env, K)
		K.Layout = nil
		-- A sized preview far smaller than the pane.
		K.Modules.Register(Module("Cooldowns", { defaults = { size = 38 } }))
		local cooldowns = { { type = "header", label = "Cooldowns" }, { type = "slider", key = "size", label = "Size", help = "Socket size.", min = 20, max = 60, step = 1 } }
		cooldowns.preview = function(parent)
			local frame = env.CreateFrame("Frame", nil, parent)
			frame:SetSize(SMALL_W, SMALL_H)
			frame.fill = frame:CreateTexture(nil, "ARTWORK")
			frame.fill:SetAllPoints(frame)
			frame.fill:SetColorTexture(0, 1, 0, 1)
			return frame
		end
		K.Options.Register("Cooldowns", cooldowns)
		-- A sized preview a little narrower than the pane: it grows to the pane's width, under the cap.
		K.Modules.Register(Module("Meters", { defaults = { rows = 5 } }))
		local meters = { { type = "header", label = "Meters" }, { type = "slider", key = "rows", label = "Rows", help = "Rows shown.", min = 1, max = 10, step = 1 } }
		meters.preview = function(parent)
			local frame = env.CreateFrame("Frame", nil, parent)
			local room = parent:GetWidth()
			frame:SetSize(room / NEAR, 80)
			return frame
		end
		K.Options.Register("Meters", meters)
		-- An unsized preview, as the unit frames draw: it fills its parent and centres a strip of its own size inside.
		K.Modules.Register(Module("UnitFrames", { defaults = { width = 220 } }))
		local frames = { { type = "header", label = "Frames" }, { type = "slider", key = "width", label = "Width", help = "Frame width.", min = 100, max = 400, step = 1 } }
		frames.preview = function(parent)
			local frame = env.CreateFrame("Frame", nil, parent)
			frame:SetAllPoints(parent)
			frame.strip = env.CreateFrame("Frame", nil, frame)
			frame.strip:SetPoint("CENTER", frame, "CENTER", 0, 0)
			frame.strip:SetSize(STRIP_W, STRIP_H)
			frame.strip.fill = frame.strip:CreateTexture(nil, "ARTWORK")
			frame.strip.fill:SetAllPoints(frame.strip)
			frame.strip.fill:SetColorTexture(1, 0, 0, 1)
			-- A soft glow behind the strip bleeds far past it, as the sigil's scrim does: decor, not content.
			frame.strip.glow = frame.strip:CreateTexture(nil, "BACKGROUND")
			frame.strip.glow:SetTexture("Interface\\AddOns\\KstyleUI\\Media\\Textures\\Glow.png")
			frame.strip.glow:SetPoint("CENTER", frame.strip, "CENTER", 0, 0)
			frame.strip.glow:SetSize(STRIP_W + 2 * GLOW_PAD, STRIP_H + 2 * GLOW_PAD)
			frame.Refresh = function(self)
				refreshes[#refreshes + 1] = self:GetWidth()
			end
			return frame
		end
		K.Options.Register("UnitFrames", frames)
		-- An unsized preview whose content spans its parent: nothing to gain, so it keeps scale 1.
		K.Modules.Register(Module("GroupFrames", { defaults = { rows = 5 } }))
		local groups = { { type = "header", label = "Groups" }, { type = "slider", key = "rows", label = "Rows", help = "Rows shown.", min = 1, max = 10, step = 1 } }
		groups.preview = function(parent)
			local frame = env.CreateFrame("Frame", nil, parent)
			frame:SetAllPoints(parent)
			frame.band = env.CreateFrame("Frame", nil, frame)
			frame.band:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
			frame.band:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
			frame.band:SetHeight(120)
			frame.band.fill = frame.band:CreateTexture(nil, "ARTWORK")
			frame.band.fill:SetAllPoints(frame.band)
			frame.band.fill:SetColorTexture(0, 0, 1, 1)
			return frame
		end
		K.Options.Register("GroupFrames", groups)
		-- An unsized preview that fits its own content to its room, as the unit frames do: a strip at 80% of the
		-- width it is given. Magnifying it only shrinks its room, so the host leaves it at scale 1.
		K.Modules.Register(Module("Chat", { defaults = { lines = 5 } }))
		local chat = { { type = "header", label = "Chat" }, { type = "slider", key = "lines", label = "Lines", help = "Lines kept.", min = 1, max = 10, step = 1 } }
		chat.preview = function(parent)
			local frame = env.CreateFrame("Frame", nil, parent)
			frame:SetAllPoints(parent)
			frame.band = env.CreateFrame("Frame", nil, frame)
			frame.band:SetPoint("CENTER", frame, "CENTER", 0, 0)
			frame.band.fill = frame.band:CreateTexture(nil, "ARTWORK")
			frame.band.fill:SetAllPoints(frame.band)
			frame.band.fill:SetColorTexture(1, 1, 0, 1)
			frame.Refresh = function(self)
				refreshes.chat = (refreshes.chat or 0) + 1
				local room = self:GetWidth()
				self.band:SetSize(type(room) == "number" and room * SELF_FIT or 100, 30)
			end
			frame:Refresh()
			return frame
		end
		K.Options.Register("Chat", chat)
	end,
})

local function settle()
	env.RunTimers()
	W.Settle(env)
	env.RunTimers()
end

local function rect(object)
	Scene.Build(env, {})
	local x, y, w, h = Scene.Rect(env, object)
	assert(x, "the rect of " .. tostring(object) .. " resolves")
	return { left = x, right = x + w, top = y, bottom = y + h }
end

local function inside(inner, outer, what)
	assert(inner.left >= outer.left - SLACK and inner.right <= outer.right + SLACK and inner.top >= outer.top - SLACK and inner.bottom <= outer.bottom + SLACK,
		string.format("%s lies inside the pane: %.1f..%.1f x %.1f..%.1f against %.1f..%.1f x %.1f..%.1f", what, inner.left, inner.right, inner.top, inner.bottom, outer.left, outer.right, outer.top, outer.bottom))
end

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < EPS
end

-- The first page shown is the unsized preview, and it is magnified on that first show, before anything has
-- measured a font string (the pane sizes its caption, so the holder's rect resolves at once).
K.Options.Open("UnitFrames")
settle()
local pane = ns.Window.Parts().preview
local holder = pane.holder
local holderW, holderH = holder:GetWidth(), holder:GetHeight()
assert(pane.current and pane.current.strip, "the UnitFrames preview is current first")
assert(near(pane.current:GetScale(), 1.25), "the unsized preview is magnified on its first show, got " .. tostring(pane.current:GetScale()))

-- A sized preview far smaller than the pane grows to the cap, centred.
K.Options.Open("Cooldowns")
settle()
assert(holderW > SMALL_W * 1.25 and holderH > SMALL_H * 1.25, "the pane has room to magnify the small preview")
local current = pane.current
assert(current and current.fill, "the Cooldowns preview is current")
assert(holderW == holder:GetWidth(), "the holder keeps its size from page to page")
assert(near(current:GetScale(), ns.Preview.MAX_SCALE) and near(ns.Preview.MAX_SCALE, 1.25), "a small sized preview grows to the 1.25 cap, got " .. tostring(current:GetScale()))
local shown = rect(current)
inside(shown, rect(pane), "the magnified preview")
assert(near(shown.right - shown.left, SMALL_W * 1.25), "it draws at 1.25 times its size")

-- A sized preview a little narrower than the pane grows to the pane's width.
K.Options.Open("Meters")
settle()
current = pane.current
assert(current and not current.fill and not current.strip, "the Meters preview is current")
assert(near(current:GetScale(), NEAR), "a preview a tenth narrower than the pane grows to its width, got " .. tostring(current:GetScale()))
inside(rect(current), rect(pane), "the width-fitted preview")

-- An unsized preview whose drawn content is small is magnified by its scale, refreshed in its smaller room, and stays
-- inside; the glow behind the strip, wider than the pane, does not count as content.
K.Options.Open("UnitFrames")
settle()
current = pane.current
assert(current and current.strip, "the UnitFrames preview is current")
assert(STRIP_W + 2 * GLOW_PAD > holderW, "the glow is wider than the pane, so only decor exclusion lets the strip grow")
assert(near(current:GetScale(), 1.25), "an unsized preview with small content is magnified to the cap, got " .. tostring(current:GetScale()))
assert(refreshes[#refreshes] and near(refreshes[#refreshes], holderW / 1.25), "the preview was refreshed in its magnified room: " .. tostring(refreshes[#refreshes]) .. " against " .. holderW / 1.25)
local strip = rect(current.strip)
inside(strip, rect(pane), "the magnified strip")
assert(near(strip.right - strip.left, STRIP_W * 1.25), "the strip draws at 1.25 times its size, got " .. (strip.right - strip.left))

-- An unsized preview whose content spans the pane keeps scale 1.
K.Options.Open("GroupFrames")
settle()
current = pane.current
assert(current and current.band, "the GroupFrames preview is current")
assert(near(current:GetScale(), 1), "content that fills the pane is not magnified, got " .. tostring(current:GetScale()))
inside(rect(current.band), rect(pane), "the full-width band")

-- Back on the small content, the host settles on the same scale again rather than compounding.
K.Options.Open("UnitFrames")
settle()
current = pane.current
assert(near(current:GetScale(), 1.25), "re-showing keeps the cap, got " .. tostring(current:GetScale()))
ns.Preview.Refresh(pane, "UnitFrames")
settle()
assert(near(current:GetScale(), 1.25), "a refresh keeps the cap, got " .. tostring(current:GetScale()))
inside(rect(current.strip), rect(pane), "the strip after a refresh")

-- A preview that fits itself to its room gains nothing from magnification: the host tries once, sees the drawn
-- width unchanged, and leaves it at scale 1; later refreshes do not try again at the same pane size.
K.Options.Open("Chat")
settle()
current = pane.current
assert(current and current.band, "the Chat preview is current")
assert(near(current:GetScale(), 1), "a self-fitting preview stays at scale 1, got " .. tostring(current:GetScale()))
local band = rect(current.band)
assert(near(band.right - band.left, holderW * SELF_FIT), "the band keeps its share of the pane: " .. (band.right - band.left) .. " against " .. holderW * SELF_FIT)
local tried = refreshes.chat
ns.Preview.Refresh(pane, "Chat")
settle()
assert(refreshes.chat == tried + 1, "a later refresh refreshes once, without another magnification trial: " .. tostring(refreshes.chat - tried))
assert(near(current:GetScale(), 1), "and keeps scale 1")

assert(#env._errors == 0, "errors: " .. table.concat(env._errors, "\n"))
print("options preview fill ok")
