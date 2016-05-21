session['defensesActive_Main'] = true
session['defensesActive_Mine Exit Corridor'] = false
session['defensesActive_Mineral Processing'] = true

function toggleDefenses(circuit, value)
	circuit = circuit or 'Main'
	if value == nil then
		value = not session['defensesActive_'..circuit]
	end
	session['defensesActive_'..circuit] = value
	
	popup(circuit..' circuit:\n'..
		(session['defensesActive_'..circuit]
		and [[
Emergency alarm deactivated.
Defense systems disabled.]]
		or [[
Emergency alarm activated.
Defense systems enabled.]]))
end

-- if the geemer boss isn't killed then remove all geemers (and subclasses) from the objects
function removeGeemersIfBossNotKilled()
	if session.geemerBossKilled then return end
	local Geemer = require 'zeta.script.obj.geemer'
	for _,obj in ipairs(game.objs) do
		if obj:isa(Geemer) then obj.remove = true end
	end
end
