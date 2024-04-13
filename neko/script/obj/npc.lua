local NPC = require 'base.script.obj.object':subclass()

NPC.sprite = 'neko'
NPC.useGravity = false
NPC.solidFlags = 0
NPC.touchFlags = NPC.SOLID_YES
NPC.blockFlags = 0

function NPC:playerLook(player)
	local threads = require 'base.script.singleton.threads'
	if self.text then
		threads:add(function()
			player:popupMessage(self.text)
		end)
	end
	if self.use then
		local sandbox = require 'base.script.singleton.sandbox'
		sandbox(self.use, 'self, player', self, player)
	end
end

return NPC
