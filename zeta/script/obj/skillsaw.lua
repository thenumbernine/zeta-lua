local class = require 'ext.class'
local Weapon = require 'zeta.script.obj.weapon'
local game = require 'base.script.singleton.game'

local Skillsaw = class(Weapon)
Skillsaw.sprite = 'sawblade'	-- TODO sprite of its own
Skillsaw.rotCenter = {.5, .5}
Skillsaw.drawScale = {1,1}
Skillsaw.drawOffsetStanding = {.5, .5}
Skillsaw.shotDelay = 0
Skillsaw.shotSound = 'skillsaw'
Skillsaw.rapidFire = true
Skillsaw.shotSpeed = 1	-- so 'vel' will be 1
Skillsaw.playSoundDuration = .5

function Skillsaw:playShotSound(player)
	if self.nextSoundTime and game.time < self.nextSoundTime then return end
	self.nextSoundTime = game.time + self.playSoundDuration
	Skillsaw.super.playShotSound(self, player)
end

local USES_CELLS = false
Skillsaw.powerDuration = 3	-- how long the attack lasts
Skillsaw.rechargeDelay = 2	-- extra delay
function Skillsaw:canShoot(player)
	-- doing the attack so long as the player holds the button down?
	if self.attackEndTime and game.time < self.attackEndTime then
		return true
	end
	-- recharging
	if self.nextAttackTime and game.time < self.nextAttackTime then
		return false
	end

	if not Skillsaw.super.canShoot(self, player) then return end
if USES_CELLS then	
	if player.ammoCells < 5 then return end
	player.ammoCells = player.ammoCells - 5
end
	-- it takes 10 seconds to recharge 5 of 5 cells
	-- it takes 5 seconds to recharge 5 of 10 cells
	self.attackEndTime = game.time + self.powerDuration
	self.nextAttackTime = game.time + self.powerDuration + self.rechargeDelay
if USES_CELLS then
	player.nextRechargeCellsTime = self.nextAttackTime
end	
	return true
end

Skillsaw.attackDist = 1.4
Skillsaw.attackAngleSpread = 180
Skillsaw.damage = 1
function Skillsaw:doShoot(player, pos, vel)
	if self.power < .5 then return end
	-- don't allow cells to recharge
	for _,obj in ipairs(game.objs) do
		if obj ~= player
		and obj.takeDamage then
			local delta = (obj.pos + {0,.5}) - (player.pos + self.drawOffset)
			local length = delta:length()
			if length < self.attackDist * self.attackDist
			and delta:dot(vel) / length > math.cos(math.rad(.5*self.attackAngleSpread))
			then
				obj:takeDamage(self.damage, player, self, nil)	-- side? really?
			end
		end
	end
end

Skillsaw.angle = 0
Skillsaw.t = 0
Skillsaw.rotation = 3000
Skillsaw.power = 0
Skillsaw.powerChangeRate = 3
Skillsaw.drawOffsetLookingUp = {0,1}
function Skillsaw:doUpdateHeldPosition()
	local player = self.heldby
	Skillsaw.super.doUpdateHeldPosition(self)
	if player.inputUpDown > 0 then
		self.drawOffset = self.drawOffsetLookingUp
	end
	local dt = game.deltaTime
	
	if self.attackEndTime
	and game.time < self.attackEndTime
	and player.inputShoot
	then
		self.power = math.min(1, self.power + dt / self.powerChangeRate)
	else
		--[[ TODO if we just let up then stop the attack.  gotta recharge.
		if self.attackTime and game.time < self.attackEndTime
		and not player.inputShot
		and player.inputShotLast
		then
			player.attackEndTime = game.time - 1
			player.nextAttackTime = game.time + self.rechargeDuration
		end
		--]]	
		self.power = math.max(0, self.power - dt / self.powerChangeRate)
	end
		
	self.t = self.t + self.power * dt
	self.angle = self.rotation * self.t
end

return Skillsaw
