local class = require 'ext.class'
local BlasterShot = require 'zeta.script.obj.blastershot'
local Weapon = require 'zeta.script.obj.weapon'
local Blaster = class(Weapon)
Blaster.sprite = 'blaster'
Blaster.shotDelay = .1
Blaster.shotSpeed = 35
Blaster.shotClass = BlasterShot
Blaster.shotSound = 'shoot'
Blaster.shotOffset = vec2(0, .45)

--[[ if you want the blaster to use cells 
function Blaster:canShoot(player)
	local game = require 'base.script.singleton.game'
	if not Blaster.super.canShoot(self, player) then return end
	if player.ammoCells < 1 then return end
	player.ammoCells = player.ammoCells - 1
	player.nextRechargeCellsTime = game.time + .5 
	return true
end
--]]

return Blaster
