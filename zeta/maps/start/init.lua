local Turret = require 'zeta.script.obj.turret'
local Barrier = require 'zeta.script.obj.barrier'
local defensesDeactivated = false
function toggleDefenses()
	defensesDeactivated = not defensesDeactivated
	for _,obj in ipairs(game.objs) do
		if obj:isa(Turret)
		or obj:isa(Barrier)
		then
			obj.deactivated = defensesDeactivated
		end
	end
	popup(defensesDeactivated
	and [[
Emergency alarm deactivated.
Defense systems disabled.]]
	or [[
Emergency alarm activated.
Defense systems enabled.]])
end
