local class = require 'ext.class'
local Grenade = require 'zeta.script.obj.grenade'
local Weapon  = require 'zeta.script.obj.weapon'
local GrenadeLauncher = class(Weapon)
GrenadeLauncher.sprite = 'grenadelauncher'
GrenadeLauncher.shotDelay = .5
GrenadeLauncher.shotSpeed = 18
GrenadeLauncher.shotUpSpeed = 7
GrenadeLauncher.shotSound = 'fire-grenade'
GrenadeLauncher.rotCenter = {.25,.5}
GrenadeLauncher.drawOffsetStanding = {.5, .25}
GrenadeLauncher.shotClass = Grenade 
GrenadeLauncher.shotOffset = {.5, .5}
GrenadeLauncher.ammo = 'Grenades'

function GrenadeLauncher:getShotPosVel(player)
	local pos, vel = GrenadeLauncher.super.getShotPosVel(self, player)
	vel[2] = vel[2] + self.shotUpSpeed
	return pos, vel
end

return GrenadeLauncher
