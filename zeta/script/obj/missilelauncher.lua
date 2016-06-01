local Missile = require 'zeta.script.obj.missile'
local Weapon  = require 'zeta.script.obj.weapon'
local MissileLauncher = class(Weapon)
MissileLauncher.sprite = 'missilelauncher'
MissileLauncher.shotDelay = .5
MissileLauncher.shotSpeed = 50
MissileLauncher.shotSound = 'explode1'
MissileLauncher.rotCenter = {.25,.5}
MissileLauncher.shotClass = Missile 
MissileLauncher.ammo = 'Missiles'

return MissileLauncher
