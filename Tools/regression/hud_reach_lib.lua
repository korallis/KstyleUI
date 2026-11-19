-- hud_reach_lib.lua: the complete live HUD keeps its visible parts and mouse targets apart and inside the screen margin.
local Suite = dofile("Tools/regression/suite_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local Guard = dofile("Tools/render/guard.lua")
local Meters = dofile("Tools/regression/meters_env.lua")
local Minimap = dofile("Tools/regression/minimap_env.lua")
local Cooldowns = dofile("Tools/regression/cooldowns_env.lua")
local DataBars = dofile("Tools/regression/databars_env.lua")
local Chat = dofile("Tools/regression/chat_env.lua")
local Group = dofile("Tools/regression/group_env.lua")
local EditMode = dofile("Tools/regression/editmode_fake.lua")
local Auras = dofile("Tools/regression/auras_env.lua")
local Hud = dofile("Tools/render/scenes/hud.lua")

local Reach = {}
Reach.screens = {
    {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160}, {3456,2234}, {2383,1540}, {2560,1600}, {3440,1440}, {3840,1080},
    {1280,720}, {1366,768}, {2560,1080}, {1452,1089}, {1685,1123}, {2642,1651}, {1280,1024},
    {1920,1200}, {2043,855}, {4236,1495}, {2266,1000}, {3247,1359},
}

function Reach.New(width, height, style, layout, saved)
	return Suite.New(saved, width or 1920, height or 1080, function(e)
		e.SetQuiet(true)
		e.UnitCastingInfo=function(unit)
			if unit=="player" or unit=="target" or unit=="focus" or unit:match("^boss") then return "Fireball","Fireball",135813,0,30000,false,"Cast-1",false,133,1 end
		end
		e._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
		Meters.Game(e)
		e.GetNumShapeshiftForms = function() return 10 end
		e.GetShapeshiftFormInfo = function(i) return 135036, false, true, 15473+i end
		e.GetPetActionInfo = function(i) return "Pet action " .. i, 135809, false, false, false, false, 8000+i end
		local possess=e.CreateFrame("Frame","PossessActionBar",e.UIParent)
		possess:SetSize(64,30)
		possess.actionButtons={}
		for i=1,2 do
			local button=e.CreateFrame("CheckButton",nil,possess)
			button:SetSize(30,30)
			button:SetPoint("LEFT",possess,"LEFT",(i-1)*34,0)
			button.icon=button:CreateTexture(nil,"ARTWORK")
			button.icon:SetAllPoints(button)
			button.icon:SetTexture(135036)
			possess.actionButtons[i]=button
		end
		Group.Install(e)
		e.UnitReaction = function() return 2 end
		Minimap.Blizzard(e, {})
		Cooldowns.Install(e)
		Cooldowns.Viewers(e)
		DataBars.Game(e)
		DataBars.Blizzard(e)
		local glyphs={}
		for _,button in ipairs(DataBars.MICRO) do glyphs[button[1]]=135036 end
		DataBars.Menus(e,{glyphs=glyphs,bags={[31]=135036,[32]=135036,[33]=135036,[34]=135036,[35]=135036},backpack=135036,keyring=135036})
		Chat.Install(e, {})
		e._reachEdit={saved={},active=1}
		EditMode.Install(e,e._reachEdit)
		for _, unit in ipairs({"target", "focus", "focustarget", "targettarget", "pet", "boss1", "boss2", "boss3", "boss4", "boss5"}) do
			e._units[unit] = {name=unit=="focustarget" and "ToF" or unit=="targettarget" and "ToT" or unit, class="WARRIOR", reaction=2, hostile=true, exists=true, health=3000, maxHealth=4000, power=60, maxPower=100, level=60}
		end
		Group.SetRoster(e,"raid",Group.Members(40,function(i,m) m.name="M" .. i end),{name="Tester",class="HUNTER",health=3000,maxHealth=4000,power=60,maxPower=100,level=60},true)
		e._units.target.auras = {}
		for i=1,7 do e._units.target.auras[i]={id=i,icon=135813,left=i*3,harmful=true,mine=true} end
		e._target = true
		e._threat.player = {false,1,60,50,600000}
		for i=1,5 do
			e._session.combatSources[i] = {name="MEM" .. i,classFilename="WARRIOR",totalAmount=3000-i*100,amountPerSecond=100-i,sourceDisplayType=1,isLocalPlayer=false}
			e._threat["raid" .. i] = {i==1,1,100-i*10,100-i*10,1000000-i*10000}
		end
		e._session.maxAmount,e._session.totalAmount,e._session.durationSeconds=3000,14000,30
	end, function(_, K)
		if saved then return end
		K.Setup.EditMode.CountTracked(function(group) return group=="buffs" and 6 or group=="bars" and 2 or 12 end)
		local choice=K.Setup.NewChoice()
		choice.hudStyle,choice.layout=style or "frames",layout or "DPS"
		assert(K.Setup.Apply(choice),"full HUD setup must apply before login")
		for _,bar in ipairs({"bar1","bar2","bar3","bar4","bar5","bar6","pet","stance"}) do
			K.Options.Write("ActionBars",bar .. ".enabled",true)
			if bar~="stance" then K.Options.Write("ActionBars",bar .. ".showEmpty",true) end
		end
		K.Options.Write("DataBars","menus.always",true)
		K.Options.Write("Meters","followRole",false)
		K.Options.Write("Meters","threat.shown",true)
	end)
end

function Reach.Populate(env)
	local fan=env._addons.KstyleUI_UnitFrames.Frames.Get("target").views[1].auras.fan
	if fan and fan.enabled then
		for _,container in ipairs(fan.containers) do
			Auras.Assign(env,container,"debuffs",7)
			local group=container._groups.debuffs
			Hud.PlaceAuras(container,group,group.active,7)
			for i,button in ipairs(group.active) do button._aura.icon:SetTexture(env.Secret(135813)); button._aura.timer:SetText(i*3 .. "s") end
		end
	end
	for _,unit in ipairs({"player","target","focus","boss1","boss2","boss3","boss4","boss5"}) do env.FireEvent("UNIT_SPELLCAST_START",unit,"Cast-1",133) end
	env.KstyleUI.Motion.Settle()
	for _,kind in ipairs({"player","target"}) do
		local casts=env._addons.KstyleUI_UnitFrames.CastBars
		local cast=(casts.ElementLive(kind) and casts.Get(kind) or casts.Inline(kind))[1]
		assert(cast.frame:IsVisible() and cast.frame:GetEffectiveAlpha()>0,"the full HUD fixture must show the " .. kind .. " cast")
	end
	for _,id in ipairs({"micro","bags"}) do
		local content=env._addons.KstyleUI_DataBars.Menus.Content(id)
		assert(content:IsVisible() and content:GetEffectiveAlpha()>0,"the full HUD fixture must reveal the " .. id .. " buttons")
	end
	local meters=env._addons.KstyleUI_Meters
	assert(meters.Damage.list.panel:IsVisible() and meters.Threat.list.panel:IsVisible(),"the full HUD fixture must show both meter cards")
	for _, group in ipairs({"essential","utility"}) do
		env._addons.KstyleUI_Cooldowns.Mirror.Row(group):SetCount(12)
	end
	local K=env.KstyleUI
	local layout=K.Layout.Setting("preset")
	K.Setup.EditMode.Restyle(layout,K.Setup.Story(layout,false))
	local written=assert(EditMode.Named(env._reachEdit,"KstyleUI " .. layout))
	for _,view in ipairs({{"BuffIconCooldownViewer",EditMode.BUFF_ICON,6},{"BuffBarCooldownViewer",EditMode.BUFF_BAR,2}}) do
		local items={}
		for i=1,view[3] do items[i]={id=i,icon=135813,name="Tracked buff " .. i,left=12,total=30} end
		Cooldowns.Native(env,view[1],assert(EditMode.Find(written,EditMode.VIEWER,view[2])),items,tostring)
	end
	local ns=env._addons.KstyleUI_Auras
	for _,name in ipairs({"buffs","debuffs"}) do
		local desc=ns.Panel.Group(name)
		Auras.Assign(env,desc.container,name,10)
		local group=desc.container._groups[name]
		Hud.PlaceAuras(desc.container,group,group.active,desc.ctx.group.columns)
		for _,button in ipairs(group.active) do button._aura.icon:SetTexture(env.Secret(135813)); button._aura.timer:SetText("30s") end
	end
end

function Reach.Run(wantedStyle, wantedLayout, wantedScreen)
	local screens = Reach.screens
	local firstScreen = type(wantedScreen)=="table" and wantedScreen[1] or wantedScreen=="small" and 10 or wantedScreen=="cases" and 19 or 1
	local lastScreen = type(wantedScreen)=="table" and wantedScreen[2] or firstScreen+2
	local allowed = {
		-- The secure party and raid headers are mutually exclusive in the game.
		["groupframes.party/groupframes.raid"] = true,
		-- Bar 1 owns the common tray behind both action rows; its art cannot intercept clicks.
		["actionbars.bar1/actionbars.bar2"] = true,
		-- The Orbs tray's arms sit behind the two health/resource rings in the same assembly.
		["actionbars.bar1/unitframes.player"] = wantedStyle=="orbs" or nil,
		-- The Medallions crest and XP track sit on the common slab, and XP continues behind the crest.
		["actionbars.bar1/actionbars.hub"] = wantedStyle=="medallions" or nil,
		["actionbars.bar1/databars.xp"] = wantedStyle=="medallions" or nil,
		["actionbars.hub/databars.xp"] = wantedStyle=="medallions" or nil,
	}
	local failures, checked = {}, 0
	local strata={WORLD=0,BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
	local function stratum(frame)
		while frame do
			local value=frame._state.FrameStrata
			if value then return strata[value[1]] end
			frame=frame._parent
		end
		return strata.MEDIUM
	end
	local function fail(label, key, why)
		local line = label .. ": " .. key .. ": " .. why
		if not failures[line] then failures[line] = true; print(line) end
	end
	local function overlap(a, b, slack)
		if a.circle then a,b=b,a end
		if b.circle then
			local radius=b[3]/2
			local cx,cy=b[1]+radius,b[2]+b[4]/2
			local dx,dy=math.max(a[1]-cx,0,cx-a[1]-a[3]),math.max(a[2]-cy,0,cy-a[2]-a[4])
			return dx*dx+dy*dy<(radius-slack)*(radius-slack)
		end
		return math.min(a[1]+a[3], b[1]+b[3])-math.max(a[1], b[1]) > slack
			and math.min(a[2]+a[4], b[2]+b[4])-math.max(a[2], b[2]) > slack
	end
	local function pair(a, b)
		return a < b and a .. "/" .. b or b .. "/" .. a
	end

	local env, K = Reach.New(nil,nil,wantedStyle,wantedLayout)
	local choice = K.Setup.NewChoice()
	for _, style in ipairs({"frames", "orbs", "medallions"}) do
		if not wantedStyle or wantedStyle == style then
			allowed["actionbars.bar1/unitframes.player"]=style=="orbs"
			allowed["actionbars.bar1/actionbars.hub"],allowed["actionbars.bar1/databars.xp"],allowed["actionbars.hub/databars.xp"]=style=="medallions",style=="medallions",style=="medallions"
			for _, layout in ipairs(wantedLayout and {wantedLayout} or {"DPS", "Tank", "Healer"}) do
				choice.hudStyle, choice.layout = style, layout
				if K.HudStyle.Current()~=style or K.Layout.Setting("preset")~=layout then assert(K.Setup.Apply(choice), "full HUD setup must apply") end
				K.Options.Write("Meters", "threat.shown", true)
				env.RunTimers()
				for _, arrangement in ipairs({"centred", "spread"}) do
					K.Options.Write("Layout", "arrangement", arrangement)
					for index, screen in ipairs(screens) do
						if type(wantedScreen)=="number" and wantedScreen==index or type(wantedScreen)~="number" and index>=firstScreen and index<=lastScreen then
							local w,h = screen[1],screen[2]
							env.GetPhysicalScreenSize = function() return w,h end
							env.UIParent._width = 768*w/h/env.UIParent._scale
							env.FireEvent("DISPLAY_SIZE_CHANGED")
							env.RunTimers()
							Reach.Populate(env)
							local label = string.format("%s %s %s %dx%d", style,layout,arrangement,w,h)
							assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": fixture errors: " .. tostring(env._errors[1]))
							local owners, groups = {}, {}
							for _, element in ipairs(K.Layout.Elements()) do
								if K.Setup.Layouts.Element(element.key) or element.key=="skins.guide" or element.key=="skins.quests" or element.key=="unitframes.crestDebuffs" then
									owners[K.Layout.Element(element.key).frame] = element.key
								end
							end
							owners[env.BuffIconCooldownViewer]="cooldowns.buffs"
							owners[env.BuffBarCooldownViewer]="cooldowns.bars"
							local strip=env._addons.KstyleUI_DataBars.Strip.view
							local micro=env._addons.KstyleUI_DataBars.Menus.Content("micro")
							owners[micro]="databars.micro"
							allowed["actionbars.bar1/databars.strip"],allowed["actionbars.hub/databars.strip"],allowed["databars.strip/databars.xp"]=strip.slab~=nil,strip.slab~=nil,strip.slab~=nil
							for _,name in ipairs({"buffs","debuffs"}) do owners[env._addons.KstyleUI_Auras.Panel.Group(name).host]="auras." .. name end
							if style=="orbs" then
								for _,kind in ipairs({"health","power"}) do owners[assert(env._addons.KstyleUI_UnitFrames.Orbs.Get(kind))]="unitframes.player" end
								owners[assert(env._addons.KstyleUI_UnitFrames.Orbs.Tray())]="actionbars.bar1"
							end
							if style=="medallions" then
								local slab=env._addons.KstyleUI_ActionBars.Slab
								owners[assert(slab.frame)]="actionbars.bar1"
								owners[assert(slab.hub)]="actionbars.hub"
							end
							local function owner(object)
								while object and not owners[object] do object=object._parent end
								return object and owners[object]
							end
							local scene = Scene.Build(env, {paths=function(path) return type(path)=="string" and path or nil end})
							local pixel = 1080/h
							local margin = K.Tokens.Size("screenMargin")*K.Scale.AppliedUserScale()
							local width = w*1080/h
							local topMenu=strip.topBar and micro:GetParent()==strip.frame
							allowed["databars.micro/databars.strip"]=topMenu
							local bar=topMenu and {Scene.Rect(env,strip.frame)}
							local dockDrop=strip.slab and 15*K.Scale.AppliedUserScale() or 0
							local function add(key, item)
									local r=item.rect
									local edge = key == "databars.strip" and K.Setup.Layouts.DataBarHeight(style) and 0 or margin
									local top=topMenu and key=="databars.micro" and 0 or edge
									local bottomMargin=(key=="databars.rep" or key=="databars.honor") and math.max(0,margin-dockDrop) or edge
									if topMenu and key=="databars.micro" then
										assert(r[2]>=bar[2]-pixel and r[2]+r[4]<=bar[2]+bar[4]+pixel,"the docked menu must stay inside the top bar")
									end
									if r[1]<edge-pixel or r[2]<top-pixel or r[1]+r[3]>width-edge+pixel or r[2]+r[4]>1080-bottomMargin+pixel then
										fail(label,key,"outside screen margin; move the default inward and reserve its full ornament/label bounds (" .. (item.text or item.file or item.kind) .. " " .. table.concat(r,",") .. ")")
									end
									groups[key]=groups[key] or {}
									local group=groups[key]
									group[#group+1]=item
									local box=group.bounds
									if box then
										local right,bottom=math.max(box[1]+box[3],r[1]+r[3]),math.max(box[2]+box[4],r[2]+r[4])
										box[1],box[2]=math.min(box[1],r[1]),math.min(box[2],r[2])
										box[3],box[4]=right-box[1],bottom-box[2]
									else group.bounds={unpack(r)} end
							end
							for _, item in ipairs(scene.items) do
								local key = owner(item.object)
								local file = item.file or item.path or ""
								-- Soft lighting/shadows have transparent padding and deliberately bleed; solid ornaments stay checked.
								if key and not (style=="orbs" and key=="unitframes.player") and not file:find("Shadow",1,true) and not file:find("Glow.png",1,true) and not file:find("PortraitSheen.png",1,true) then add(key,item) end
							end
							local solver, clicks = Scene.RectSolver(env), {}
							if style=="medallions" then
								local face=env._addons.KstyleUI_Minimap.Map.face
								local glass={}
								for _,card in ipairs(Guard.Cards(scene)) do glass[card.frame]=card.glass end
								for _,part in ipairs({{face.zone,1},{face.clock,2},{face.meridiem,2},{face.coords,2}}) do
									if part[1]:IsVisible() then
										local text,plate={Scene.RectIn(solver,part[1])},assert(glass[face.plaques[part[2]]])
										if text[1]<plate[1]-pixel or text[2]<plate[2]-pixel or text[1]+text[3]>plate[1]+plate[3]+pixel or text[2]+text[4]>plate[2]+plate[4]+pixel then
											fail(label,"minimap.main", "caption spills outside its plaque; size the plaque to the minimum font height")
										end
									end
								end
							end
							if style=="orbs" then
								for _,kind in ipairs({"health","power"}) do
									local rect={Scene.RectIn(solver,env._addons.KstyleUI_UnitFrames.Orbs.Get(kind))}
									rect.circle=true
									add("unitframes.player",{kind="circle",rect=rect})
								end
							end
							for _, frame in ipairs(env._frames) do
								local key=owner(frame)
								local mouse=frame:IsMouseEnabled() or frame._mouse~=false and (frame._type=="Button" or frame._type=="CheckButton")
								if key and frame:IsVisible() and mouse and env.Look(frame:GetAlpha())>0 then
									local rect={Scene.RectIn(solver,frame)}
									assert(#rect==4,label .. ": " .. key .. ": clickable bounds must resolve")
									local click={kind="click",rect=rect,key=key,object=frame}
									clicks[#clicks+1]=click
									add(key,click)
								end
							end
							-- Disabled/empty slots keep a reservation too, so enabling a spare never hides another control.
							local L=K.Setup.Layouts
							local state=L.PrepareFits(layout,w,h,{},nil,style)
							local rx,ry,_,rh=Scene.RectIn(solver,K.Scale.Root())
							local scale=K.Scale.AppliedUserScale()
							local rw,rootHeight=K.Layout.RootSize()
							for i,element in ipairs(L.ELEMENTS) do
								local key=element.key
								if not groups[key] and (key~="consumables.bar" or env._addons.KstyleUI_ActionBars.Consumables.header and env._addons.KstyleUI_ActionBars.Consumables.header:IsShown()) and not (style=="orbs" and key=="unitframes.player") then
									local size=state.sizes[i]
									local p=L.Place(layout,style,K.Scale.Aspect(),key,K.Scale.Band())
									local l,b,r,t=L.Rect({width=size[1],height=size[2],offsetX=size[3],offsetY=size[4]},p,rw,rootHeight)
									add(key,{kind="reserve",rect={rx+l*scale,ry+rh-t*scale,(r-l)*scale,(t-b)*scale}})
								end
							end
							local story=L.Story(layout,rootHeight,true,style,rw)
							for _,card in pairs(story) do
								if type(card)=="table" and card.key and not groups[card.key] then
									local l,b,r,t=L.Rect(card,card,rw,rootHeight)
									add(card.key,{kind="reserve",rect={rx+l*scale,ry+rh-t*scale,(r-l)*scale,(t-b)*scale}})
								end
							end
							for _,element in ipairs(L.ELEMENTS) do
								assert(groups[element.key] or element.key=="consumables.bar" and not (env._addons.KstyleUI_ActionBars.Consumables.header and env._addons.KstyleUI_ActionBars.Consumables.header:IsShown()) or style=="orbs" and element.key=="unitframes.player",label .. ": missing HUD bounds for " .. element.key)
							end
							for i,a in ipairs(clicks) do
								for j=i+1,#clicks do
									local b=clicks[j]
									if a.key~=b.key and pair(a.key,b.key)~="groupframes.party/groupframes.raid" and overlap(a.rect,b.rect,pixel*0.01) then
										fail(label,pair(a.key,b.key),"mouse targets cover one another; move the defaults apart")
									end
								end
								for key,items in pairs(groups) do
									if key~=a.key and allowed[pair(a.key,key)] and pair(a.key,key)~="groupframes.party/groupframes.raid" then
										for _,item in ipairs(items) do
											local frame=item.object and item.object._parent
											local above=frame and (stratum(frame)>stratum(a.object) or stratum(frame)==stratum(a.object) and frame:GetFrameLevel()>a.object:GetFrameLevel())
											if above and Guard.Hides(item) and overlap(a.rect,item.rect,pixel*0.01) then
												fail(label,pair(a.key,key),"opaque art covers a mouse target; keep the shared tray below its buttons")
											end
										end
									end
								end
							end
							for a, first in pairs(groups) do
								for b, second in pairs(groups) do
									if a<b and not allowed[pair(a,b)] and overlap(first.bounds,second.bounds,pixel*0.01) then
										local hit=false
										for _,r in ipairs(first) do
											for _,s in ipairs(second) do
									if overlap(r.rect,s.rect,pixel*0.01) then hit=(r.text or r.file or r.kind) .. " " .. table.concat(r.rect,",") .. " / " .. (s.text or s.file or s.kind) .. " " .. table.concat(s.rect,","); break end
											end
											if hit then break end
										end
									if hit then fail(label,pair(a,b),"overlap; separate the defaults using their full placed bounds (" .. hit .. ")") end
									end
								end
							end
							checked=checked+1
						end
					end
				end
			end
		end
	end
	if wantedStyle=="frames" and wantedLayout=="DPS" and wantedScreen==nil then
		K.Options.Write("Layout","arrangement","centred")
		env.RunTimers()
		K.Options.Write("HudStyle","style","frames")
		for _,key in ipairs({"chat.main","minimap.main","unitframes.player","unitframes.target"}) do
			assert(K.Layout.Update(key,{anchor="BOTTOMLEFT",x=-5000,y=-5000},true))
			env.RunTimers()
			local left,bottom=K.Layout.Rect(key)
			if left+K.Scale.Origin()<K.Tokens.Size("screenMargin") or bottom<K.Tokens.Size("screenMargin") then
				fail("saved",key,"off-screen saved position must display inside the margin; clamp display geometry without rewriting Store.Layout")
			end
			assert(K.Store.Layout()[key].x==-5000 and K.Store.Layout()[key].y==-5000,"display clamp must preserve the saved position")
			local shown={Scene.Rect(env,K.Layout.Element(key).frame)}
			local margin=K.Tokens.Size("screenMargin")*K.Scale.AppliedUserScale()
			assert(shown[1]>=margin and shown[2]+shown[4]<=1080-margin+1e-8,"the actual frame must display on screen, not just Layout.Rect")
			local pixel=K.Scale.Pixel(1)
			local x,y=K.Scale.Origin()>0 and -math.floor(K.Scale.Origin()/2/pixel)*pixel or 400*pixel,400*pixel
			assert(K.Layout.Update(key,{anchor="BOTTOMLEFT",x=x,y=y},true))
			env.RunTimers()
			left,bottom=K.Layout.Rect(key)
			assert(math.abs(left-x)<1e-8 and math.abs(bottom-y)<1e-8,"on-screen custom position must move zero pixels")
			shown={Scene.Rect(env,K.Layout.Element(key).frame)}
			local rootX=Scene.Rect(env,K.Scale.Root())
			assert(math.abs(shown[1]-rootX-x*K.Scale.AppliedUserScale())<1e-8 and math.abs(1080-shown[2]-shown[4]-y*K.Scale.AppliedUserScale())<1e-8,"the actual on-screen frame must move zero pixels")
		end
	end
	assert(next(failures)==nil, "HUD reach failed; move the named defaults, preserve custom positions, and rerun test-hud-reach.lua")
	print("HUD reach ok: " .. checked .. " style/layout/arrangement/screen combinations")
end

function Reach.SavedColumns(style, index, arrangement)
	local Core = dofile("Tools/regression/core_env.lua")
	local screen = Reach.screens[index]
	local env, K = Reach.New(screen[1], screen[2], style, "DPS")
	K.Options.Write("Layout", "arrangement", arrangement or "centred")
	K.Options.Write("Appearance", "uiScale", 0.6)
	for _, key in ipairs({"unitframes.player", "unitframes.target"}) do
		assert(K.Layout.Update(key, {anchor="BOTTOMLEFT", x=-5000, y=-5000}, true))
	end
	env.RunTimers()
	env.FireEvent("PLAYER_LOGOUT")
	local saved = Core.DeepCopy(env.KstyleUIDB)
	local before = Core.DeepCopy(K.Store.Layout())
	env, K = Reach.New(screen[1], screen[2], style, "DPS", saved)
	assert(Core.DeepEqual(K.Store.Layout(), before), "loading off-screen columns must not rewrite saved positions")
	K.Setup.EditMode.Write("DPS", K.Setup.Story("DPS", false), true)
	Reach.Populate(env)
	local scene = Scene.Build(env, {paths=function(path) return type(path)=="string" and path or nil end})
	local frames = {}
	for _, key in ipairs({"unitframes.player", "unitframes.target"}) do frames[K.Layout.Element(key).frame]=key end
	if style=="orbs" then for _,kind in ipairs({"health","power"}) do frames[env._addons.KstyleUI_UnitFrames.Orbs.Get(kind)]="unitframes.player" end end
	local columns = { ["unitframes.player"]={items={},screen=scene.screen}, ["unitframes.target"]={items={},screen=scene.screen} }
	local scale, pixel = K.Scale.AppliedUserScale(), 1080 / screen[2]
	local margin, width = K.Tokens.Size("screenMargin") * scale, screen[1] * 1080 / screen[2]
	for _, item in ipairs(scene.items) do
		local object = item.object
		while object and not frames[object] do object=object._parent end
		if object then table.insert(columns[frames[object]].items,item) end
		local file = item.file or item.path or ""
		if object and not file:find("Shadow",1,true) and not file:find("Glow.png",1,true) and not file:find("PortraitSheen.png",1,true) then
			local r=item.rect
			assert(r[1]>=margin-pixel and r[2]>=margin-pixel and r[1]+r[3]<=width-margin+pixel and r[2]+r[4]<=1080-margin+pixel, style .. ": clamp full column art inside the physical screen margin without changing Store: " .. (item.text or item.file or item.kind) .. " " .. table.concat(r,","))
		end
	end
	for _,column in pairs(columns) do
		local findings=Guard.Check(column)
		assert(#findings==0, "saved columns must still pass the render guard: " .. table.concat(Guard.Lines(findings,{},{},"strict"),"\n"))
	end
	assert(Core.DeepEqual(K.Store.Layout(), before), "relayout must leave saved column positions unchanged")
	pixel = K.Scale.Pixel(1)
	local x = K.Scale.Origin()>0 and -math.floor(K.Scale.Origin()/2/pixel)*pixel or 400*pixel
	local y = 400*pixel
	for _,key in ipairs({"unitframes.player","unitframes.target"}) do assert(K.Layout.Update(key,{anchor="BOTTOMLEFT",x=x,y=y},true)) end
	env.RunTimers()
	env.FireEvent("PLAYER_LOGOUT")
	saved, before = Core.DeepCopy(env.KstyleUIDB), Core.DeepCopy(K.Store.Layout())
	env, K = Reach.New(screen[1],screen[2],style,"DPS",saved)
	assert(Core.DeepEqual(K.Store.Layout(),before),"loading valid saved columns must preserve Store")
	for _,key in ipairs({"unitframes.player","unitframes.target"}) do
		local left,bottom=K.Layout.Rect(key)
		assert(math.abs(left-x)<1e-8 and math.abs(bottom-y)<1e-8,"valid saved columns must move zero pixels after load")
		local rect={Scene.Rect(env,K.Layout.Element(key).frame)}
		local rootX=Scene.Rect(env,K.Scale.Root())
		assert(math.abs(rect[1]-rootX-x*K.Scale.AppliedUserScale())<1e-8 and math.abs(1080-rect[2]-rect[4]-y*K.Scale.AppliedUserScale())<1e-8,"valid saved columns must draw at exactly their stored position")
	end
	print("saved columns ok: " .. style .. " " .. screen[1] .. "x" .. screen[2] .. " " .. (arrangement or "centred"))
end

return Reach
