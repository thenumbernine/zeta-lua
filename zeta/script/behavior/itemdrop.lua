local game = require 'base.script.singleton.game'
local itemDropBehavior = function(parentClass)
	--assert(parentClass.isa({class=parentClass}, require 'zeta.script.obj.takesdamage'))
	
	local ItemDropTemplate = class(parentClass)

	--ItemDropTemplate.itemDrops maps from spawn classes to probabilities that they occur (assumed to be normalized)
	function ItemDropTemplate:die(...)
		local player = game.players[1]
		if player and self.itemDrops then
			local r = math.random()
			for classname,chance in pairs(self.itemDrops) do
				if r <= chance then
					local itemClass = require(classname)
				
					if classname == 'zeta.script.obj.healthitem' and player.health == player.maxHealth then
					elseif classname == 'zeta.script.obj.cellitem' and player.ammoCells == player.maxAmmoCells then
					elseif classname == 'zeta.script.obj.grenadeitem' and player.ammoGrenades == player.maxAmmoGrenades then
					elseif classname == 'zeta.script.obj.missileitem' and player.ammoMissiles == player.maxAmmoMissiles then
					else
						itemClass{pos = self.pos}
					end

					break
				end
				r = r - chance
			end
		end
		return ItemDropTemplate.super.die(self, ...)
	end

	return ItemDropTemplate
end

return itemDropBehavior
