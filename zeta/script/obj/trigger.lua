local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local Trigger = class(Object)
Trigger.solid = false
Trigger.nextTriggerTime = -1
Trigger.wait = math.huge	-- wait forever, so default trigger only once
Trigger.pushPriority = math.huge	-- can't push

function Trigger:init(args)
	Trigger.super.init(self, args)
	self.trigger = args.trigger
	self.wait = args.wait
end

-- use pretouch so we don't block
function Trigger:pretouch(other, side)
	if game.time < self.nextTriggerTime then return end
	self.nextTriggerTime = game.time + self.wait

	-- by default, triggers only operate when players touch them
	-- maybe later I'll have a flag for enemies too
	local Hero = require 'zeta.script.obj.hero'
	if not other:isa(Hero) then return true end

	-- TODO this has a lot in common with terminal's "use"
	if self.trigger then
		local sandbox = require 'zeta.script.sandbox'
		sandbox(self.trigger, 'self, other, side', self, other, side)
		-- TODO once by default?
	end
end

function Trigger:draw(R, viewBBox)

end

return Trigger
