local PlasmaShot = require 'zeta.script.obj.plasmashot'
local Weapon = require 'zeta.script.obj.weapon'
local game = require 'base.script.singleton.game'
local PlasmaRifle = class(Weapon)
PlasmaRifle.sprite = 'plasma-rifle'
PlasmaRifle.shotDelay = .05
PlasmaRifle.shotSpeed = 40
PlasmaRifle.shotSound = 'shoot'
PlasmaRifle.rapidFire = true
PlasmaRifle.shotClass = PlasmaShot
PlasmaRifle.drawOffsetStanding = {.5, .25}
PlasmaRifle.rotCenter = {.25, .35}
PlasmaRifle.shotOffset = {0, .45}
PlasmaRifle.ammo = 'Cells'

PlasmaRifle.spreadAngle = 5
function PlasmaRifle:getShotPosVel(player)
	local pos, vel = PlasmaRifle.super.getShotPosVel(self, player)
	local angle = (math.random() - .5) * self.spreadAngle
	local theta = math.rad(angle)
	local x, y = math.cos(theta), math.sin(theta)
	vel[1], vel[2] = x * vel[1] - y * vel[2], x * vel[2] + y * vel[1]
	return pos, vel
end

function PlasmaRifle:canShoot(player)
	if not PlasmaRifle.super.canShoot(self, player) then return end
	player.nextRechargeCellsTime = game.time + .5 
	return true
end

return PlasmaRifle
