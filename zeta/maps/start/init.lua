session.defensesDeactivated = false

function toggleDefenses()
	session.defensesDeactivated = not session.defensesDeactivated
	popup(session.defensesDeactivated
	and [[
Emergency alarm deactivated.
Defense systems disabled.]]
	or [[
Emergency alarm activated.
Defense systems enabled.]])
end

-- if the geemer boss isn't killed then remove all geemers (and subclasses) from the objects
function removeGeemersIfBossNotKilled()
	if session.geemerBossKilled then return end
	local Geemer = require 'zeta.script.obj.geemer'
	for _,obj in ipairs(game.objs) do
		if obj:isa(Geemer) then obj.remove = true end
	end
end
