local class = require 'ext.class'
local Geemer = require 'zeta.script.obj.geemer'

local RedGeemer = class(Geemer)
RedGeemer.color = {1,.5,.5,1}
RedGeemer.maxHealth = 2

return RedGeemer
