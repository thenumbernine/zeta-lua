local function hurtsToTouchBehavior(parentClass)
	local HurtsToTouchTemplate = class(parentClass)
--[[	
	local Mario = require 'mario.script.obj.mario'
	function HurtsToTouchTemplate:makesMeAngry(other)
		return Mario.is(other)
	end

	function HurtsToTouchTemplate:touch(other, ...)
		local superTouch = HurtsToTouchTemplate.super.touch
		if superTouch and superTouch(self, other, side, ...) then return true end
		
		if self:makesMeAngry(other)
		and other.hit
		then
			other:hit(self)
		end
	end
--]]
	return HurtsToTouchTemplate 
end

return hurtsToTouchBehavior
