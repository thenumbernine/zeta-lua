local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local BallnChain = class(GameObject)
BallnChain.sprite = 'ballnchain'
BallnChain.pushPriority = 10
BallnChain.useGravity = false
BallnChain.collidesWithWorld = false
BallnChain.bbox = {min={-.4, 0}, max={.4, 1.8}}
BallnChain.spinJumpImmune = true

BallnChain.armDist = 3
BallnChain.degreesPerSecond = 20	--90

function BallnChain:init(args)
	BallnChain.super.init(self, args)
	
	self.anchorPos = {unpack(self.pos)}
end

function BallnChain:update(dt)
	BallnChain.super.update(self, dt)

	self:moveToPos(
		self.anchorPos[1] + self.armDist * math.cos(math.rad(self.degreesPerSecond * game.time)),
		self.anchorPos[2] + self.armDist * math.sin(math.rad(self.degreesPerSecond * game.time)) - 1)		-- sprites are bottom-center-anchored
end

function BallnChain:touch(other, side)
	--local Mario = require 'mario.script.obj.mario'
	--print('other:isa(Mario)',other:isa(Mario),'other.spinjumping',other.spinjumping,'side',side)
	--print(debug.traceback())
	--if other:isa(Mario) and other.spinjumping and side == 'up' then return end
	--if other.hitByEnemy then other:hitByEnemy(self) end
end


return BallnChain