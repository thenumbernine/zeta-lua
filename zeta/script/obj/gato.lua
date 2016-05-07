local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local takesDamageBehavior = require 'zeta.script.obj.takesdamage'
local box2 = require 'vec.box2'

local Gato = class(takesDamageBehavior(Object))
Gato.sprite = 'gato'
Gato.solid = true
Gato.bbox = box2(-1, 0, 1, 2)
Gato.maxHealth = math.huge

return Gato
