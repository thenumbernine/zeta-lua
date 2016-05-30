local itemDropBehavior = function(parentClass)
	--assert(parentClass.isa({class=parentClass}, require 'zeta.script.obj.takesdamage'))
	
	local ItemDropTemplate = class(parentClass)

	--ItemDropTemplate.itemDrops maps from spawn classes to probabilities that they occur (assumed to be normalized)
	function ItemDropTemplate:die(...)
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
		return ItemDropTemplate.super.die(self, ...)
	end

	return ItemDropTemplate
end

return itemDropBehavior
