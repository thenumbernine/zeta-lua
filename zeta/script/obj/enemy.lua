local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local takesDamageBehavior = require 'zeta.script.obj.takesdamage'
local modio = require 'base.script.singleton.modio'

local Enemy = class(takesDamageBehavior(Object))

function Enemy:init(args)
	Enemy.super.init(self, args)
	self.onDie = args.onDie
end

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

	if self.onDie then
		local sandbox = modio:require 'script.sandbox'
		sandbox(self.onDie,
			'self, damage, attacker, inflicter, side',
			self, damage, attacker, inflicter, side)
	end
end

return Enemy
