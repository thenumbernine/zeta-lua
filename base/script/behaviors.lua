-- accepts parentClass, behavior1, behavior2, ...
-- applies them, in order
local class = require 'ext.class'
local function behaviors(baseClass, ...)
	local classObj = baseClass
	for i=1,select('#', ...) do
		local behavior = select(i, ...)
		classObj = behavior(classObj)
	end
	return class(classObj)
end
return behaviors
