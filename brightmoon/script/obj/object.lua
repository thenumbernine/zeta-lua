local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local vec2 = require 'vec.vec2'

local BMObject = class(GameObject)
BMObject.lastUID = 1

-- static
function BMObject.getNewUID()
	local uid = BMObject.lastUID
	BMObject.lastUID = BMObject.lastUID + 1
	return uid
end

function BMObject:init(args)
	BMObject.super.init(self, args)

	self.uid = BMObject.getNewUID()
	self.name = args.name
	
	self.objs = table()
	if args.tex then
		local filename = modio:find(args.tex)
		if filename then
			self.tex = texsys:load(framefile)
		else
			print("unable to find object texture "..tostring(args.tex))
		end
	end
	if args.objs then
		for _,sarg in ipairs(args.objs) do
			local sarg = table(sarg)
			local spawnName = assert(sarg.spawn)
			local spawnClass = require(spawnName)
			sarg.spawn = nil
			sarg.pos = vec2(-1,-1)
			local obj = spawnClass(sarg)
			self.objs:insert(obj)
		end
	end
end

function BMObject:inspect()
	
end

function BMObject:draw(R, ...)
	local gl = R.gl
	gl.glPushName(self.uid)
	BMObject.super.draw(self, R, ...)
	gl.glPopName()
end

return BMObject
