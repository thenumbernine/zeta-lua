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

function removeBossGeemerWalls()
	local wall = findObjNamed 'geemer-right-wall'
	if wall then wall.remove = true end
	local wall = findObjNamed 'geemer-left-wall'
	if wall then wall.remove = true end
end
