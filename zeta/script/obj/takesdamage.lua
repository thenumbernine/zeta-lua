local class = require 'ext.class'
local math = require 'ext.math'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local function takesDamageBehavior(parentClass)
	local TakesDamageTemplate = class(parentClass)
	
	TakesDamageTemplate.maxHealth = TakesDamageTemplate.maxHealth or 1
	TakesDamageTemplate.invincibleEndTime = -1

	function TakesDamageTemplate:init(...)
		TakesDamageTemplate.super.init(self, ...)
		self.health = self.maxHealth
	end

	function TakesDamageTemplate:takeDamage(damage, attacker, inflicter, side)
		if self.invincibleEndTime >= game.time then return end
		
		local FloatText = require 'zeta.script.obj.floattext'
		FloatText{pos=self.pos, text=tostring(damage)}
		
		self.health = math.clamp(self.health - damage, 0, self.maxHealth)
		if damage >= 0 then
			if self.health > 0 then 
				if self.hit then
					self:hit(damage, attacker, inflicter, side)
				end
			else
				self:playSound('explode1')
				self:die(damage, attacker, inflicter, side)
			end
		end
	end

	function TakesDamageTemplate:die(damage, attacker, inflicter, side)
		self.remove = true
		self:playSound('explode2')
	end

	return TakesDamageTemplate
end

return takesDamageBehavior
