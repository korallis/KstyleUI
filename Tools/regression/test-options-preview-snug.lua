-- test-options-preview-snug.lua: the settings window never shows a large empty preview box (KSTY-60 item 27). A page
-- with no preview (Profiles, About, Elements, a module without one) hides the pane and its rows take the pane's width,
-- clear of the Layout Mode and Reset buttons; a page whose preview draws little fits the pane's card to what it draws;
-- a preview that fills the room keeps the full pane; and the pane comes back with its page.
local O = dofile("Tools/regression/options_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local W = O.W
local Module = W.CoreEnv.Module

local SMALL_W, SMALL_H = 120, 40
local SLACK = 1

local env, K, ns = O.New({
	setup = function(e)
		e._textWidth = function(text, fontPath, size)
			return Scene.TextWidth(Scene.PlainText(text), size, fontPath)
		end
	end,
	before = function(e, K)
		K.Layout = nil
		K.Modules.Register(Module("Cooldowns", { defaults = { size = 38 } }))
		local small = { { type = "header", label = "Cooldowns" }, { type = "slider", key = "size", label = "Size", help = "Socket size.", min = 20, max = 60, step = 1 } }
		small.preview = function(parent)
			local frame = e.CreateFrame("Frame", nil, parent)
			frame:SetSize(SMALL_W, SMALL_H)
			frame.fill = frame:CreateTexture(nil, "ARTWORK")
			frame.fill:SetAllPoints(frame)
			frame.fill:SetColorTexture(0, 1, 0, 1)
			return frame
		end
		K.Options.Register("Cooldowns", small)
		K.Modules.Register(Module("GroupFrames", { defaults = { rows = 5 } }))
		local tall = { { type = "header", label = "Groups" }, { type = "slider", key = "rows", label = "Rows", help = "Rows shown.", min = 1, max = 10, step = 1 } }
		tall.preview = function(parent)
			local frame = e.CreateFrame("Frame", nil, parent)
			frame:SetAllPoints(parent)
			frame.column = e.CreateFrame("Frame", nil, frame)
			frame.column:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
			frame.column:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
			frame.column.fill = frame.column:CreateTexture(nil, "ARTWORK")
			frame.column.fill:SetAllPoints(frame.column)
			frame.column.fill:SetColorTexture(0, 0, 1, 1)
			return frame
		end
		K.Options.Register("GroupFrames", tall)
		K.Modules.Register(Module("Chat", { defaults = { lines = 5 } }))
		K.Options.Register("Chat", { { type = "header", label = "Chat" }, { type = "slider", key = "lines", label = "Lines", help = "Lines kept.", min = 1, max = 10, step = 1 } })
	end,
})

local function settle()
	env.RunTimers()
	W.Settle(env)
	Scene.Build(env, {})
	env.RunTimers()
	W.Settle(env)
end

local function rect(object)
	Scene.Build(env, {})
	local x, y, w, h = Scene.Rect(env, object)
	assert(x, "the rect of " .. tostring(object) .. " resolves")
	return { left = x, right = x + w, top = y, bottom = y + h }
end

local function open(page)
	K.Options.Open(page)
	settle()
	local parts = ns.Window.Parts()
	return parts.preview, parts
end

local win
local function inset()
	return K.Widgets.WindowInset(win)
end

-- General shows the kit sample, so the pane is there and the rows stop short of it.
local pane, parts = open("General")
win = ns.Window.Frame()
assert(pane:IsShown() and pane.current, "General shows its sample preview")
local narrow = parts.content:GetWidth()
local room = pane.room or pane:GetHeight()
assert(type(room) == "number" and room > 0, "the window gives the pane its full room")

-- Pages with no preview hide the pane, and the rows take its width, clear of the footer buttons.
for _, page in ipairs({ "Profiles", "About", "Elements", "Chat" }) do
	pane, parts = open(page)
	assert(not pane:IsShown(), page .. ": a page with no preview shows no preview box")
	local content, frame = rect(parts.content), rect(win)
	assert(math.abs(content.right - (frame.right - inset())) <= SLACK, page .. ": the rows reach the window's inset, got " .. content.right .. " against " .. (frame.right - inset()))
	assert(parts.content:GetWidth() > narrow, page .. ": the rows are wider than beside a preview")
	local button = rect(parts.layoutButton)
	assert(content.bottom <= button.top + SLACK, page .. ": the rows end above Layout Mode and Reset")
end

-- A small preview gets a card sized to it, not the full room: no large empty box under it.
pane = open("Cooldowns")
assert(pane:IsShown() and pane.current and pane.current.fill, "the Cooldowns preview shows")
local box, drawn = rect(pane), rect(pane.current)
assert(pane:GetHeight() < room / 2, "the pane fits its small preview, " .. pane:GetHeight() .. " of " .. room)
assert(drawn.top >= box.top and drawn.bottom <= box.bottom and drawn.left >= box.left and drawn.right <= box.right, "the preview lies inside its card")
local below = box.bottom - drawn.bottom
assert(below <= inset() + 8 + SLACK, "the card ends a padding under the preview, not " .. below .. " units below it")
local scale = pane.current:GetScale()
ns.Preview.Refresh(pane, "Cooldowns")
settle()
assert(pane:GetHeight() < room / 2 and math.abs(pane.current:GetScale() - scale) < 0.001, "a refresh keeps the fitted card and the scale")

-- A preview that fills its room keeps the whole pane.
pane = open("GroupFrames")
assert(pane:IsShown() and math.abs(pane:GetHeight() - room) <= SLACK, "a preview that fills the room keeps the full pane, " .. pane:GetHeight() .. " of " .. room)

-- Back on General the pane returns and the rows give it back its width.
pane, parts = open("General")
assert(pane:IsShown() and math.abs(parts.content:GetWidth() - narrow) <= SLACK, "the pane comes back with General and the rows narrow again")
assert(pane:GetHeight() < room, "the sample's card fits the sample")

assert(#env._errors == 0, "errors: " .. table.concat(env._errors, "\n"))
print("options preview snug ok")
