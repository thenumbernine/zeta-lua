local class = require 'ext.class'
local game = require 'base.script.singleton.game'
local behaviors = require 'base.script.behaviors'

local BallnChain = behaviors(
	require 'base.script.obj.object',
	require 'mario.script.behavior.hurtstotouch')
BallnChain.sprite = 'ballnchain'
BallnChain.pushPriority = 10
BallnChain.useGravity = false
BallnChain.solidFlags = BallnChain.SOLID_NO
BallnChain.touchFlags = -1
BallnChain.blockFlags = 0
BallnChain.touchDamage = 3
BallnChain.bbox = {min={-.4, 0}, max={.4, 1.8}}

BallnChain.armDist = 3
BallnChain.degreesPerSecond = 90

function BallnChain:init(args)
	BallnChain.super.init(self, args)

	self.angle = self.angle or math.random(360)
	self.anchorPos = {unpack(self.pos)}
end

function BallnChain:update(dt)
	BallnChain.super.update(self, dt)

	self.angle = self.angle + dt * self.degreesPerSecond

	self:moveToPos(
		self.anchorPos[1] + self.armDist * math.cos(math.rad(self.angle)),
		self.anchorPos[2] + self.armDist * math.sin(math.rad(self.angle)) - 1)		-- sprites are bottom-center-anchored
end

return BallnChain
