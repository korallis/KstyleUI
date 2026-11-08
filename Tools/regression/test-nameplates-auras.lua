-- test-nameplates-auras.lua: nameplates show the player's debuffs on the unit through the AuraContainer engine, laid out and styled from the settings.
local N = dofile("Tools/regression/nameplates_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

local GROUP = "debuffs"

local function group(plate)
	return plate.auras._groups[GROUP]
end

-- Tiled(K, frame, icon) -> true when the frame draws the kit's chamfered tile and the icon is cut to the
-- kit's chamfered icon mask, as the cast icon and the level badge on the same plate are.
local function Tiled(K, frame, icon)
	local tilePath = K.Tokens.Texture("chamferTile")
	local maskPath = K.Tokens.Texture("iconMask")
	local tile = false
	for _, object in ipairs(A.Descendants(frame)) do
		if object:GetObjectType() == "Texture" and object ~= icon and object:GetTexture() == tilePath then
			tile = true
		end
	end
	local mask = icon:GetNumMaskTextures() == 1 and icon:GetMaskTexture(1)
	return tile and mask and mask:GetTexture() == maskPath
end

local function Whole(K, units)
	local n = units / K.Scale.Pixel()
	return math.abs(n - math.floor(n + 0.5)) < 1e-6
end

-- The pure rules ------------------------------------------------------------------------------------

do
	local _, _, ns = N.New({ enable = false })
	local Logic = ns.Logic
	assert(Logic.AuraFilter(true) == "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY")
	assert(Logic.AuraFilter(false) == "HARMFUL|PLAYER")
	local anchor, h, v = Logic.AuraGrowth("RIGHT", "UP")
	assert(anchor == "BOTTOMLEFT" and h == "Right" and v == "Up")
	anchor, h, v = Logic.AuraGrowth("LEFT", "DOWN")
	assert(anchor == "TOPRIGHT" and h == "Left" and v == "Down")
	assert(Logic.AuraGrowth("SIDEWAYS", "UP") == "BOTTOMLEFT", "an unknown direction grows right")
	assert(Logic.AuraLineSize(5, 18, 2) == 98, "five 18-unit icons with 2-unit gaps make a 98-unit line")
	assert(Logic.AuraLineSize(1, 18, 2) == 18)
	local x, y = Logic.AuraOffset(1, 3, 18, 2, "RIGHT", "UP")
	assert(x == 0 and y == 0, "the first icon sits on the anchor")
	x, y = Logic.AuraOffset(3, 3, 18, 2, "RIGHT", "UP")
	assert(x == 40 and y == 0, "the third goes two steps right")
	x, y = Logic.AuraOffset(4, 3, 18, 2, "RIGHT", "UP")
	assert(x == 0 and y == 20, "the fourth starts a new row above")
	x, y = Logic.AuraOffset(5, 3, 18, 2, "LEFT", "DOWN")
	assert(x == -20 and y == -20, "growing left and down mirrors both axes")
end

-- Each plate gets a container with one group: the player's harmful auras -----------------------------

do
	local env, _, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local container = plate.auras
	assert(container and container._groups, "the plate builds a CustomAuraContainerTemplate container")
	assert(container:GetParent() == plate, "the container is the plate's child")
	assert(container._unit == "nameplate1", "the container follows the plate's unit")
	assert(container._editModePreview == false, "Edit Mode's fake auras stay off the plates")
	local g = group(plate)
	assert(g, "the container has the debuff group")
	assert(g.filter == "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY", "the group shows the player's debuffs: " .. g.filter)
	assert(g.maxFrameCount == ns.Settings.Get("debuffs.columns") * ns.Settings.Get("debuffs.rows"), "columns times rows icons at most")
	local size = ns.Settings.Get("debuffs.size")
	assert(g.layout.elementWidth == size and g.layout.elementHeight == size, "the icons take the size setting")
	assert(g.layout.elementSpacing == ns.Settings.Get("debuffs.spacing"), "and the spacing")

	local button = g.frames[1]
	assert(button._aura.icon and button._aura.icon:GetObjectType() == "Texture", "each button gets an icon")
	assert(button._aura.cooldown, "a cooldown swipe")
	assert(button._aura.count, "a stack count")
	assert(button._aura.timer, "and a time left")
	local w, h = button:GetSize()
	assert(w == size and h == size, "buttons start at the icon size")
	do
		local K = select(2, N.New())
		local skin = (button:GetChildren())
		local Widgets, Tokens = K.Widgets, K.Tokens
		local fr, fg, fb = Tokens.Color("buttonFill")
		local rr, rg, rb = Widgets.IconRim()
		local body, rim = false, false
		for _, region in ipairs({ skin:GetRegions() }) do
			local set = region._state.Texture and region._state.Texture[1]
			local cr, cg, cb = region:GetVertexColor()
			if type(cr) == "number" and set == (Tokens.Texture("chamferTile")) and math.abs(cr - fr) < 1e-3 and math.abs(cg - fg) < 1e-3 and math.abs(cb - fb) < 1e-3 then
				body = true
			elseif type(cr) == "number" and math.abs(cr - rr) < 1e-3 and math.abs(cg - rg) < 1e-3 and math.abs(cb - rb) < 1e-3 then
				rim = true
			end
		end
		assert(body, "the tile's body is the near-black button fill every square icon shares")
		assert(rim, "its hairline rests on the accent rim, as an action button")
	end
	assert(N.Last(button, "EnableMouse")[1] == false, "debuff buttons let clicks through to the world, as Blizzard's plate auras do")

	-- The flow layout: icons grow right and up from above the name, wrapping after the columns.
	local flow = container._flow
	assert(flow.anchor == "BOTTOMLEFT", "growing right and up anchors the bottom left")
	assert(flow.horizontal == env.AnchorUtil.FlowDirection.Right and flow.vertical == env.AnchorUtil.FlowDirection.Up)
	local columns, spacing = ns.Settings.Get("debuffs.columns"), ns.Settings.Get("debuffs.spacing")
	assert(math.abs(flow.lineSize - (columns * size + (columns - 1) * spacing)) < 1, "a line holds exactly the columns")
	assert(container:GetPoint(1) == "BOTTOMLEFT", "the container hangs from its growth corner")

	N.Remove(env, "nameplate1")
	assert(container._unit == "none", "a detached plate's container lets go of the unit")
	N.Add(env, "nameplate2", nil, { base = plate:GetParent() })
	assert(container._unit == "nameplate2" and plate.auras == container, "the plate reuses its container for the next unit")
end

-- Each debuff button is the kit's chamfered aura tile -----------------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local button = group(plate).frames[1]
	local aura = button._aura
	assert(Tiled(K, button, aura.icon), "a debuff is a chamfered kit tile with a masked icon, not a square on black")
	assert(N.Last(aura.cooldown, "SetSwipeTexture")[1] == K.Tokens.Texture("iconMask"), "the cooldown swipe has the icon's chamfered shape")
	local inset = K.Widgets.Border(button) * 2
	local point, _, _, x, y = aura.icon:GetPoint(1)
	assert(point == "TOPLEFT" and x == inset and y == -inset, "the icon sits two border lines inside the tile")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Debuff size and spacing land on whole physical pixels ----------------------------------------------------

do
	local env, K, ns = N.New({ width = 2560, height = 1600 })
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	assert(not Whole(K, ns.Settings.Get("debuffs.size")) and not Whole(K, ns.Settings.Get("debuffs.spacing")), "this screen puts the raw size and spacing between pixels")
	local g = group(plate)
	local layout = g.layout
	assert(Whole(K, layout.elementWidth) and Whole(K, layout.elementHeight), "the engine lays the icons out on whole pixels")
	assert(Whole(K, layout.elementSpacing) and Whole(K, layout.lineSpacing), "with whole-pixel gaps")
	local w, h = g.frames[1]:GetSize()
	assert(w == layout.elementWidth and h == layout.elementHeight, "each button is the size the layout gives it")
	local columns = ns.Settings.Get("debuffs.columns")
	local line = columns * layout.elementWidth + (columns - 1) * layout.elementSpacing
	assert(math.abs(plate.auras._flow.lineSize - line) < 1, "a line holds exactly the columns at the snapped size")

	local preview = K.Options.Preview("Nameplates")(env.CreateFrame("Frame", nil, K.Scale.Root()))
	local sample = preview.plates[1]
	local icon = sample.sampleAuras[2]
	local sw = icon:GetSize()
	local _, _, _, x = icon:GetPoint(1)
	assert(Whole(K, sw) and Whole(K, x), "the preview's sample debuffs sit on the same whole-pixel grid")
	assert(Tiled(K, icon, icon.icon), "and are the same chamfered tiles")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A theme change while auras are secret leaves the restricted buttons alone, then restyles their tiles -------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local button = group(ns.Plates.Get("nameplate1")).frames[1]
	env._aurasSecret = true
	local before = A.CallCount(button)
	K.Widgets.RestyleAll()
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(A.CallCount(button) == before, "nothing on an aura button is touched while auras are secret")
	env._aurasSecret = false
	env.RunTimers()
	assert(A.CallCount(button) > before, "the tile restyles once the auras are readable")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Settings apply to live plates; buttons wait while auras are secret -------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local container = plate.auras
	K.Options.Write("Nameplates", "debuffs.columns", 3)
	K.Options.Write("Nameplates", "debuffs.rows", 2)
	assert(group(plate).maxFrameCount == 6, "columns and rows set the count")
	K.Options.Write("Nameplates", "debuffs.growthX", "LEFT")
	K.Options.Write("Nameplates", "debuffs.growthY", "DOWN")
	assert(container._flow.anchor == "TOPRIGHT", "growing left and down anchors the top right")
	assert(container._flow.horizontal == env.AnchorUtil.FlowDirection.Left and container._flow.vertical == env.AnchorUtil.FlowDirection.Down)

	env._aurasSecret = true
	env.SetCombat(true)
	K.Options.Write("Nameplates", "debuffs.size", 24)
	assert(#env._errors == 0, "no button is touched while auras are secret: " .. tostring(env._errors[1]))
	assert(group(plate).frames[1]:GetSize() ~= 24, "the buttons wait")
	assert(group(plate).layout.elementWidth == 24, "the container's layout updates at once")
	env._aurasSecret = false
	env.SetCombat(false)
	assert(group(plate).frames[1]:GetSize() == 24, "the buttons resize when the auras are readable again")

	K.Options.Write("Nameplates", "debuffs.showTime", false)
	assert(not group(plate).frames[1]._aura.timer:IsVisible(), "the time left can be switched off")
	K.Options.Write("Nameplates", "debuffs.showCount", false)
	assert(not group(plate).frames[1]._aura.count:IsVisible(), "the stack count can be switched off")

	K.Options.Write("Nameplates", "debuffs.includePlateOnly", false)
	assert(group(plate).filter == "HARMFUL|PLAYER", "the filter can leave out nameplate-only debuffs")
	K.Options.Write("Nameplates", "debuffs.enabled", false)
	assert(not container:IsShown() and container._unit == "none", "debuffs can be switched off")
	K.Options.Write("Nameplates", "debuffs.enabled", true)
	assert(container:IsShown() and container._unit == "nameplate1", "and on again")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A client without the AuraContainer engine: plates work without debuffs, and the devlog says so --------

do
	local env, K, ns = N.New({ noAuraContainer = true })
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	assert(plate and plate.health:IsShown(), "the plate still attaches")
	assert(not plate.auras, "with no container")
	local logged = false
	for _, entry in ipairs(K.Store.Data().devlog) do
		logged = logged or entry.message:find("AuraContainer", 1, true) ~= nil
	end
	assert(logged, "the missing engine is logged")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Auras turn secret before combat starts: the restyle waits for them without recursing --------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	env._aurasSecret = true
	local ok, err = pcall(K.Options.Write, "Nameplates", "debuffs.size", 26)
	assert(ok, "a restyle while auras are secret out of combat does not recurse: " .. tostring(err))
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(plate.auras._groups.debuffs.frames[1]:GetSize() ~= 26, "the buttons wait")
	env._aurasSecret = false
	env.RunTimers()
	assert(plate.auras._groups.debuffs.frames[1]:GetSize() == 26, "and resize once the auras are readable")
end

-- A container the engine refuses in combat is retried once after combat, not once per event ---------------

do
	local env, K, ns = N.New()
	local create = env.CreateFrame
	env.CreateFrame = function(frameType, ...)
		if frameType == "AuraContainer" and env._combat then
			error("CreateFrame: AuraContainer refused in combat")
		end
		return create(frameType, ...)
	end
	env.SetCombat(true)
	N.Add(env, "nameplate1")
	for _ = 1, 5 do
		env.FireEvent("UNIT_FLAGS", "nameplate1")
	end
	assert(K.Combat.Pending() == 1, "one retry waits, however many events arrive: " .. K.Combat.Pending())
	env.SetCombat(false)
	assert(ns.Plates.Get("nameplate1").auras, "the container is built when combat ends")
end

-- The preview draws sample debuffs on the same grid -----------------------------------------------------

do
	local env, K = N.New()
	local preview = K.Options.Preview("Nameplates")(env.CreateFrame("Frame", nil, K.Scale.Root()))
	local sample = preview.plates[1]
	assert(sample.sampleAuras and sample.sampleAuras[1]:IsShown(), "the preview shows sample debuffs")
	K.Options.Write("Nameplates", "debuffs.size", 30)
	preview:Refresh()
	assert(sample.sampleAuras[1]:GetSize() == 30, "at the icon size")
	K.Options.Write("Nameplates", "debuffs.columns", 1)
	K.Options.Write("Nameplates", "debuffs.rows", 1)
	preview:Refresh()
	assert(sample.sampleAuras[1]:IsShown() and not sample.sampleAuras[2]:IsShown(), "no more than the count")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("nameplates auras ok")
