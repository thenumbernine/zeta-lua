local class = require 'ext.class'
local SpawnInfo = class()

function SpawnInfo:init(args)
	for k,v in pairs(args) do self[k] = v end
end

function SpawnInfo:respawn()
	if not self.spawn then
		error("failed to find spawn class")
	end
	-- self.spawn is a table, so self:spawn() is actually calling the table's ctor with self as the first param (after the table itself)
	self.obj = require(self.spawn)(self)
	self.obj.spawnInfo = self
end

return SpawnInfo
