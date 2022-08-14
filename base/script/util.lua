-- TODO use ffi vec2's with x and y fields?

local vec2 = require 'vec.vec2'
dirs = {
	up = vec2(0,1),
	down = vec2(0,-1),
	left = vec2(-1,0),
	right = vec2(1,0),
}

oppositeSide = {
	up = 'down',
	down = 'up',
	left = 'right',
	right = 'left',
}

-- accepts parentClass, behavior1, behavior2, ...
-- applies them, in order
local class = require 'ext.class'
function behaviors(baseClass, ...)
	local classObj = baseClass
	for i=1,select('#', ...) do
		local behavior = select(i, ...)
		classObj = behavior(classObj)
	end
	return class(classObj)
end
