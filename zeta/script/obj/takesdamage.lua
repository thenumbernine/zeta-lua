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
	
	TakesDamageTemplate.showDamageAmount = 0
	TakesDamageTemplate.showDamageTime = -1
	function TakesDamageTemplate:showDamage()
		local FloatText = require 'zeta.script.obj.floattext'
		FloatText{pos=self.pos, text=tostring(self.showDamageAmount)}
		self.showDamageAmount = 0
		self.showDamageTime = -1
	end
	
	function TakesDamageTemplate:update(dt, ...)
		if (self.remove and self.showDamageAmount > 0)
		or (self.showDamageTime >= game.time - dt	-- last time
		and self.showDamageTime < game.time)
		then
			self:showDamage()
		end
		TakesDamageTemplate.super.update(self, dt, ...)
	end

	TakesDamageTemplate.showDamageDelay = .25
	function TakesDamageTemplate:takeDamage(damage, attacker, inflicter, side)
		if self.invincibleEndTime >= game.time then return end

		if self.modifyDamageTaken then
			damage = self:modifyDamageTaken(damage, attacker, inflicter, side) or damage
		end
		if attacker.modifyDamageGiven then
			damage = attacker:modifyDamageGiven(damage, self, inflicter, side) or damage
		end
	
		-- accum damage before showing it
		self.showDamageTime = game.time + self.showDamageDelay 
		self.showDamageAmount = self.showDamageAmount + damage

		self.health = math.clamp(self.health - damage, 0, self.maxHealth)
		if damage >= 0 then
			if self.health > 0 then 
				if self.hit then
					self:hit(damage, attacker, inflicter, side)
				end
			else
				self:die(damage, attacker, inflicter, side)
			end
		end
		
		if self.remove then self:showDamage() end
	end

	function TakesDamageTemplate:die(damage, attacker, inflicter, side)
		self.remove = true
		self:playSound('explode2')
	end

	return TakesDamageTemplate
end

return takesDamageBehavior
