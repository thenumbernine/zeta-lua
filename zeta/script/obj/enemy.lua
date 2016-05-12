local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local takesDamageBehavior = require 'zeta.script.obj.takesdamage'

local Enemy = class(takesDamageBehavior(Object))

Enemy.itemDrops = nil
function Enemy:die(damage, attacker, inflicter, side)
	if self.itemDrops then
		local r = math.random()
		for k,v in pairs(self.itemDrops) do
			if r <= v then
				local itemClass = require(k)
				itemClass{pos = self.pos}
				break
			end
			r = r - v
		end
	end
end

return Enemy
