game.session.defensesDeactivated = false
function toggleDefenses()
	game.session.defensesDeactivated = not game.session.defensesDeactivated
	popup(game.session.defensesDeactivated
	and [[
Emergency alarm deactivated.
Defense systems disabled.]]
	or [[
Emergency alarm activated.
Defense systems enabled.]])
end
