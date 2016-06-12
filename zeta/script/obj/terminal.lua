local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local Terminal = class(Object)

Terminal.sprite = 'terminal'
Terminal.useGravity = false
Terminal.solidFlags = 0
Terminal.touchFlags = Terminal.SOLID_YES
Terminal.blockFlags = 0

function Terminal:playerUse(player)
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

return Terminal
