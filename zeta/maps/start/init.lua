session['defensesActive_Main'] = true
session['defensesActive_Mine Exit Corridor'] = false
session['defensesActive_Mineral Processing'] = true

--[[
args:
	circuit = what circuit to toggle on/off.  nil means Main circuit.
	value = set the circuit directly to a value.  nil means toggle on/off.
	silent = don't announce it.  default: false.
use a single string for toggling a circuit
--]]
function toggleDefenses(args)
	if not args then args = {} end
	if type(args) == 'string' then args = {circuit=args} end
	local circuit = args.circuit or 'Main'
	
	local value = args.value
	if value == nil then
		value = not session['defensesActive_'..circuit]
	end
	session['defensesActive_'..circuit] = value

	if not args.silent then
		popup(circuit..' circuit:\n'.. (value
			and [[
Emergency alarm deactivated.
Defense systems disabled.]]
			or [[
Emergency alarm activated.
Defense systems enabled.]]))
	end
end

-- if the geemer boss isn't killed then remove all geemers (and subclasses) from the objects
function removeGeemersIfBossNotKilled()
	if session.geemerBossKilled then return end
	local Geemer = require 'zeta.script.obj.geemer'
	for _,obj in ipairs(game.objs) do
		if obj:isa(Geemer) then obj.remove = true end
	end
end
