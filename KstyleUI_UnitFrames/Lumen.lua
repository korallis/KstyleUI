-- Lumen.lua: the Lumen look's palette, gem and font roles for the unit frames: S1's tokens and textures when they exist, recipes over today's tokens until then, switched here and nowhere else.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens

local Lumen = {}
ns.Lumen = Lumen

local GEM_TURN = math.pi / 4
local GEM_TEXTURE = "gem"
local GEM_FALLBACK = "iconMask"

local RECIPES = {
	gold = { "neutral", "text", 0.25 },
	goldLit = { "neutral", "white", 0.45 },
	goldDim = { "neutral", "black", 0.42 },
	cast = { "neutral", "white", 0.28 },
	muted = { "text", "rare", 0.1 },
	deep = { "buttonFill", "black", 0.2 },
}

local ROLES = {
	name = "heading",
	cap = "heading",
	value = "number",
	caption = "body",
}

local cache = {}

local function Token(name)
	local ok, r, g, b = pcall(Tokens.Color, name)
	if ok and type(r) == "number" then
		return r, g, b
	end
	return nil
end

function Lumen.Color(name)
	local hit = cache[name]
	if hit then
		return hit[1], hit[2], hit[3]
	end
	local recipe = RECIPES[name]
	if not recipe then
		error("UnitFrames.Lumen.Color: unknown colour " .. tostring(name), 2)
	end
	local r, g, b = Token(name)
	if not r then
		local r1, g1, b1 = Tokens.Color(recipe[1])
		local r2, g2, b2 = Tokens.Color(recipe[2])
		r, g, b = Widgets.Mix(r1, g1, b1, 1, r2, g2, b2, 1, recipe[3])
	end
	cache[name] = { r, g, b }
	return r, g, b
end

function Lumen.Font(role)
	return Tokens.Font(ROLES[role] or "body")
end

local function GemPath()
	local ok, path = pcall(Tokens.Texture, GEM_TEXTURE)
	if ok and path then
		return path, false
	end
	return (Tokens.Texture(GEM_FALLBACK)), true
end

function Lumen.Gem(parent, layer)
	local gem = parent:CreateTexture(nil, layer or "OVERLAY")
	local path, turn = GemPath()
	gem:SetTexture(path)
	if turn then
		gem:SetRotation(GEM_TURN)
	end
	gem:SetVertexColor(Lumen.Color("goldLit"))
	return gem
end

Lumen.GEM_SIZE = 7
