local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local Start = class(Object)
Start.solidFlags = 0
Start.touchFlags = 0
Start.blockFlags = 0
Start.remove = true	-- always remove
return Start
