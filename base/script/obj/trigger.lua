local class = require 'ext.class'
local Object = require 'base.script.obj.object'

local Trigger = class(Object)
Trigger.solid = false

function Trigger:init(args)
	Trigger.super.init(self, args)
	self.trigger = args.trigger
end

-- use pretouch so we don't block
function Trigger:pretouch(other, side)
	-- by default, triggers only operate when players touch them
	-- maybe later I'll have a flag for enemies too
	local Hero = require 'zeta.script.obj.hero'
	if not other:isa(Hero) then return end

-- TODO this has a lot in common with terminal's "use"
	if self.trigger then
		local threads = require 'base.script.singleton.threads'
		local code = [[
local self, other, side = ...
local game = require 'base.script.singleton.game'
local level = game.level
-- notice popup() is invalid if other is not a Hero
local function popup(...) return other:popupMessage(...) end
]] .. self.trigger
		threads:add(assert(load(code)), self, other, side)
	end
end

return Trigger
