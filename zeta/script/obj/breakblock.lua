-- TODO crumble animation?
local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local takesDamageBehavior = require 'zeta.script.obj.takesdamage'
local game = require 'base.script.singleton.game'
local box2 = require 'vec.box2'

local BreakBlock = class(takesDamageBehavior(Object))
BreakBlock.solid = true
BreakBlock.useGravity = false
BreakBlock.pushPriority = math.huge
BreakBlock.bbox = box2(-.5, 0, .5, 1)
BreakBlock.maxHealth = 1
BreakBlock.solidFlags = BreakBlock.SOLID_WORLD
BreakBlock.touchFlags = 0
BreakBlock.blockFlags = 0

function BreakBlock:init(args)
	if args.health then self.maxHealth = tonumber(args.health) end
	BreakBlock.super.init(self, args)
	if args.tileIndex then self.tileIndex = tonumber(args.tileIndex) end
end

function BreakBlock:draw(R, viewBBox)
	if not self.tileIndex then return end
	local level = game.level
	local texpack = level.texpackTex
	local tilesWide = texpack.width / 16
	local tilesHigh = texpack.height / 16
	local ti = (self.tileIndex-1) % tilesWide
	local tj = (self.tileIndex-ti-1) / tilesWide
	texpack:bind()
	R:quad(
		self.pos[1]-.5, self.pos[2],
		1, 1,
		ti/tilesWide, (tj+1)/tilesHigh,
		1/tilesWide, -1/tilesHigh,
		0,
		1,1,1,1)
end

return BreakBlock
