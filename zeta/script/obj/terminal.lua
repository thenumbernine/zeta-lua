local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local Terminal = class(Object)
Terminal.sprite = 'terminal'
Terminal.solid = false
Terminal.collidesWithObjs = false

function Terminal:init(args)
	Terminal.super.init(self, args)
	self.text = args.text
	self.use = args.use
end

function Terminal:playerLook(player)
	local threads = require 'base.script.singleton.threads'
	if self.text then
		threads:add(function()
			player:popupMessage(self.text)
		end)
	end
	if self.use then
		-- TODO sandbox: http://stackoverflow.com/a/6982080/2714073
		local code = [[
local self, player = ...
local game = require 'base.script.singleton.game'
local level = game.level
local function popup(...) return player:popupMessage(...) end
]] .. self.use
		threads:add(assert(load(code)), self, player)
	end
end

return Terminal
