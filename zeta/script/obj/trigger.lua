local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local Player = require 'base.script.obj.player'
local game = require 'base.script.singleton.game'
local sandbox = require 'base.script.singleton.sandbox'

local Trigger = class(Object)

Trigger.useGravity = false
Trigger.pushPriority = math.huge	-- can't push
Trigger.nextTriggerTime = -1
Trigger.wait = math.huge	-- wait forever, so default trigger only once
Trigger.solidFlags = Trigger.SOLID_NO
Trigger.touchFlags = Trigger.SOLID_YES + Trigger.SOLID_NO
Trigger.blockFlags = 0

function Trigger:touch(other, side)
	-- by default, triggers only operate when players touch them
	-- maybe later I'll have a flag for enemies too
	if not Player:isa(other) then return true end
	
	if game.time < self.nextTriggerTime then return end
	self.nextTriggerTime = game.time + self.wait

	-- TODO this should be 'touch' callback?
	if self.trigger then
		sandbox(self.trigger, 'self, other, side', self, other, side)
	end
end

function Trigger:draw(R, viewBBox)
end

return Trigger
