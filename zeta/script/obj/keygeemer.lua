local class = require 'ext.class'
local Geemer = require 'zeta.script.obj.geemer'

local KeyGeemer = class(Geemer)

KeyGeemer.sprite = 'whitegeemer' 

function KeyGeemer:init(args)
	KeyGeemer.super.init(self, args)
	if args.color then
		self.color = vec4(table.unpack(args.color))
	end
	-- TODO or just use the .spawnInfo.dropColor?
	self.dropColor = args.dropColor
end

function KeyGeemer:takeDamage(damage, attacker, inflicter, side)
	if self.color
	and inflicter
	and inflicter.color
	and not vec4.__eq(self.color, inflicter.color)
	then
		return
	end
	return KeyGeemer.super.takeDamage(self, damage, attacker, inflicter, side)
end
	
function KeyGeemer:die(damage, attacker, inflicter, side)
	if self.dropColor then
		require 'zeta.script.obj.keyshotitem'{
			pos = self.pos + vec2(0, 1),
			color = self.dropColor,
		}
	end

	KeyGeemer.super.die(self, damage, attacker, inflicter, side)
end

return KeyGeemer 
