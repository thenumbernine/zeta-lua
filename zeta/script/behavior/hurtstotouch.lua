--[[
behavior is clever when it's templates at compile time
but when it's runtime, there is no advantage over enumerating them in an object and calling them back one by one
(except maybe tail-call optimizations)
there is a disadvantage with added recursion levels to class testing via class:isa(instance)
--]]

local class = require 'ext.class'

local function hurtsToTouchBehavior(parentClass)
	local HurtsToTouchTemplate = class(parentClass)

	function HurtsToTouchTemplate:makesMeAngry(other)
		local Hero = require 'zeta.script.obj.hero'
		return Hero:isa(other)
	end

	-- HurtsToTocuhTemplate.touchDamage = nil
	function HurtsToTouchTemplate:touch(other, side, ...)
		local superTouch = HurtsToTouchTemplate.super.touch
		if superTouch and superTouch(self, other, side, ...) then return true end
		
		if self:makesMeAngry(other) then
			other:takeDamage(self.touchDamage, self, self, side)
		end
	end

	return HurtsToTouchTemplate
end

return hurtsToTouchBehavior
