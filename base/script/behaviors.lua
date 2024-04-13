-- accepts parentClass, behavior1, behavior2, ...
-- applies them, in order
local function behaviors(baseClass, ...)
	local classObj = baseClass
	for i=1,select('#', ...) do
		local behavior = select(i, ...)
		classObj = behavior(classObj)
	end
	return classObj:subclass()
end
return behaviors
