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
