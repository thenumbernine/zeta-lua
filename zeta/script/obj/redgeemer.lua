local class = require 'ext.class'
local Geemer = require 'zeta.script.obj.geemer'

local RedGeemer = class(Geemer)
RedGeemer.sprite = 'redgeemer'
RedGeemer.maxHealth = 2

return RedGeemer
