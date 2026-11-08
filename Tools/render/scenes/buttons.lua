-- buttons.lua: every square icon button in one scene: the six action button states at the design file's
-- 62-unit showcase size and at the HUD's 34, the bag window's slots, the aura preview's buff and debuff
-- tiles, and the micro menu and bag bar, on the design file's near-black ground.
--
--   local Buttons = dofile("Tools/render/scenes/buttons.lua")
--   local scene = Buttons.Build({ rim = 1 })      -- rim: Widgets.SECONDARY_RIM for the micro menu and bag bar
--
-- Sections, in screen units from the top left (the design file's button row sits at 800,150 at 2 px/u):
--   states62  x 800, y 150, step 80      the showcase row: normal, hover, pressed, cooldown, proc, disabled
--   states34  x 800, y 290, step 44      the same six at the HUD size
--   auras     x 800, y 380               the Auras preview: sample buffs and debuffs
--   bags      the bag window where Layout puts it (bottom right)
--   menus     the micro menu and bag bar where Layout puts them (bottom right)
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene
local Hud = dofile("Tools/render/scenes/hud.lua")

local Buttons = {}

Buttons.SECTIONS = {
	states62 = { x = 800, y = 150, step = 80, size = 62 },
	states34 = { x = 800, y = 290, step = 44, size = 34 },
	auras = { x = 800, y = 380 },
}
local S = Buttons.SECTIONS
local STATES = { "Normal", "Hover", "Pressed", "Cooldown", "Proc", "Disabled" }
local GROUND = { 0.035, 0.035, 0.035 }

local function saved(module, settings)
	local section = { enabled = true }
	for k, v in pairs(settings or {}) do
		section[k] = v
	end
	return { version = 2, profiles = { Default = { [module] = section } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function shared(env)
	Common.ForceScreen(env)
	env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
	env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
	env.UnitClass = function()
		return "Warrior", "WARRIOR", 1
	end
end

local function finish(env, K, scene, what)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = what .. " error: " .. err
	end
	for i, line in ipairs(scene.log) do
		scene.log[i] = what .. ": " .. line
	end
	return scene
end

local function ticks(W, env, n)
	for _ = 1, n do
		W.Tick(env, 0.05)
	end
end

-- Ground(env, K) covers the screen with the design file's near-black, under everything.
local function Ground(env, K)
	local ground = env.CreateFrame("Frame", nil, K.Scale.Root())
	ground:SetAllPoints(K.Scale.Root())
	ground:SetFrameStrata("BACKGROUND")
	ground:SetFrameLevel(0)
	local fill = ground:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetAllPoints(ground)
	fill:SetColorTexture(GROUND[1], GROUND[2], GROUND[3], 1)
	return ground
end

-- States(K, W, root, section, labels) -> the six buttons of one row, driven into their states.
local function States(K, W, root, section, labels)
	local Widgets = K.Widgets
	local buttons = {}
	for i, name in ipairs(STATES) do
		local button = Widgets.IconButton(root, { icon = Hud.ICONS.mortalStrike, size = section.size, primary = true })
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", root, "TOPLEFT", section.x + (i - 1) * section.step, -section.y)
		buttons[i] = button
		if labels then
			local label = Widgets.Text(root, "caption", "text")
			label:SetPoint("TOP", button, "BOTTOM", 0, -12)
			Widgets.SetText(label, name)
		end
	end
	W.Enter(buttons[2])
	W.Down(buttons[3])
	buttons[4]:SetCooldownFromDuration({ remaining = 3.2, total = 8 }, false)
	buttons[4].cooldown:Show()
	buttons[4].cooldown:GetScript("OnShow")(buttons[4].cooldown)
	buttons[5]:SetProc(true)
	buttons[6]:SetUsable(false)
	return buttons
end

-- The widget kit: two rows of button states and the Auras preview.
function Buttons.Widgets(opts)
	local W = dofile("Tools/regression/widget_env.lua")
	local A = dofile("Tools/regression/auras_env.lua")
	local env, K = A.New(Common.ScreenOpts({ saved = saved("Auras"), setup = shared }))
	K.Widgets.SECONDARY_RIM = opts.rim or 1
	local root = K.Scale.Root()
	Ground(env, K)
	local big = States(K, W, root, S.states62, true)
	local small = States(K, W, root, S.states34, false)
	local canvas = env.CreateFrame("Frame", nil, root)
	canvas:SetSize(500, 200)
	canvas:SetPoint("TOPLEFT", root, "TOPLEFT", S.auras.x, -S.auras.y)
	local preview = K.Options.Preview("Auras")(canvas)
	if preview and preview.Refresh then
		preview:Refresh()
	end
	env.RunTimers()
	ticks(W, env, 40)
	local scene = Scene.Build(env, { time = env._time, hover = { [big[2]] = true, [small[2]] = true } })
	return finish(env, K, scene, "widgets")
end

-- The bag window, open, with the regression fixtures' items.
function Buttons.Bags(opts)
	local B = dofile("Tools/regression/bags_env.lua")
	local Item = B.Item
	local env, K = B.New(Common.ScreenOpts({
		setup = function(env)
			-- The bags loader builds its own options and runs the login timers itself, so the saved data
			-- that marks the setup seen goes in before the core loads.
			env.KstyleUIDB = saved("Bags")
			shared(env)
		end,
		bags = {
			[0] = { size = 16, items = { [1] = Item("potion"), [2] = Item("sword"), [3] = Item("helm"), [4] = Item("junk"), [5] = Item("hearth") } },
			[1] = { size = 8, items = { [1] = Item("cloth"), [8] = Item("ring") } },
		},
	}))
	K.Widgets.SECONDARY_RIM = opts.rim or 1
	env.ToggleAllBags()
	env.RunTimers()
	B.W.Settle(env)
	local scene = Scene.Build(env, { time = env._time })
	return finish(env, K, scene, "bags")
end

-- Stand-ins for Blizzard's micro menu and bag bar, as Tools/regression/test-databars-menus.lua builds them,
-- with warrior icons where the game draws its atlases, so the buttons read as buttons.
local MICRO = {
	{ "CharacterMicroButton" }, { "ProfessionMicroButton", "battleShout" }, { "SpellbookMicroButton", "slam" },
	{ "TalentMicroButton", "charge" }, { "LegacyMicroButton", "rend" }, { "QuestLogMicroButton", "thunderClap" },
	{ "HousingMicroButton", "execute" }, { "GuildMicroButton", "overpower" }, { "LFDMicroButton", "hamstring" },
	{ "CollectionsMicroButton", "cleave" }, { "EJMicroButton", "whirlwind" }, { "HelpMicroButton", "taunt" },
	{ "StoreMicroButton", "pummel" }, { "MainMenuMicroButton", "revenge" },
}
local BAGS = {
	{ "KeyRingButton", -2, "disarm" }, { "CharacterReagentBag0Slot", 5, "bloodFury" }, { "CharacterBag3Slot", 4, "enrage" },
	{ "CharacterBag2Slot", 3, "shieldBash" }, { "CharacterBag1Slot", 2, "retaliation" }, { "CharacterBag0Slot", 1, "sweepingStrikes" },
	{ "MainMenuBarBackpackButton", 0, "victoryRush" },
}

local function Blizzard(env)
	local container = env.CreateFrame("Frame", "MicroMenuContainer", env.UIParent)
	local menu = env.CreateFrame("Frame", "MicroMenu", container)
	for i, def in ipairs(MICRO) do
		local button = env._G[def[1]] or env.CreateFrame("Button", def[1], menu)
		button:SetParent(menu)
		button.layoutIndex = i
		if def[2] then
			local normal = button:CreateTexture(nil, "ARTWORK")
			normal:SetTexture(Hud.ICONS[def[2]])
			button:SetNormalTexture(normal)
		end
	end
	env.HelpMicroButton:Hide()
	local bags = env.CreateFrame("Frame", "BagsBar", env.UIParent)
	local cluster = env.CreateFrame("Frame", "BagSlotCluster", bags)
	local textures = {}
	for _, def in ipairs(BAGS) do
		local name, bag = def[1], def[2]
		local button = env._G[name] or env.CreateFrame("Button", name, bags)
		button:SetParent(name:match("^Character") and cluster or bags)
		button:SetID(bag == -2 and -2 or 30 + bag)
		button.icon = button:CreateTexture(nil, "BORDER")
		button.icon:SetTexture(Hud.ICONS[def[3]])
		textures[30 + bag] = Hud.ICONS[def[3]]
	end
	env.CharacterReagentBag0Slot:Hide()
	env.KEYRING_CONTAINER = -2
	env.C_Container = {
		ContainerIDToInventoryID = function(bag)
			return 30 + bag
		end,
		GetContainerNumFreeSlots = function()
			return 4
		end,
		GetContainerNumSlots = function()
			return 16
		end,
		CalculateTotalNumberOfFreeBagSlots = function()
			return 22
		end,
	}
	function env.GetInventoryItemTexture(_, slot)
		return textures[slot]
	end
	function env.SetPortraitTexture(texture)
		texture:SetColorTexture(0.33, 0.28, 0.22, 1)
	end
	function env.UpdateMicroButtons() end
	function env.MicroButtonPulse() end
	function env.MicroButtonPulseStop() end
	function env.LoadMicroButtonTextures() end
	function env.PaperDollItemSlotButton_Update() end
	function env.MainActionBar_InitializeGamepad() end
	function env.MainActionBar_InitializeMKB() end
end

-- The micro menu and bag bar, at the rim strength the options ask for.
function Buttons.Menus(opts)
	local D = dofile("Tools/regression/databars_env.lua")
	local env, K = D.New({
		saved = saved("DataBars"),
		game = { xp = 16000, xpMax = 50000, rested = 6000, level = 38 },
		setup = function(env)
			shared(env)
			Common.ForceScreen(env)
			Blizzard(env)
		end,
	})
	K.Widgets.SECONDARY_RIM = opts.rim or 1
	env.RunTimers()
	D.W.Settle(env)
	K.Widgets.RestyleAll()
	local scene = Scene.Build(env)
	return finish(env, K, scene, "menus")
end

function Buttons.Build(opts)
	opts = opts or {}
	return Scene.Merge({ Buttons.Widgets(opts), Buttons.Bags(opts), Buttons.Menus(opts) })
end

return Buttons
