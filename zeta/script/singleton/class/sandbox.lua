local Sandbox = require 'base.script.singleton.class.sandbox'
local class = require 'ext.class'
local ZetaSandbox = class(Sandbox)

-- zeta-specific
ZetaSandbox.prefixCode = ZetaSandbox.prefixCode .. [[
local function checkPlayer()
	-- hmm, sandbox.lua seems to be run before game.players[1] is set, so instead try to grab it here
	local player = game.players[1]
	if not player then
		print("couldn't find the player!")
		return
	end
	return player
end
local function popup(...)
	local player = checkPlayer()
	return player and player:popupMessage(...)
end
local function centerView(...)
	local player = checkPlayer()
	return player and player:centerView(...)
end
local function stopCenterView()
	local player = checkPlayer()
	return player and player:centerView()
end
]]

return ZetaSandbox
