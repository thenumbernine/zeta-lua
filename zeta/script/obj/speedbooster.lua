local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'
local crystalItemBehavior = require 'zeta.script.obj.crystalitem'
local SpeedBooster = class(crystalItemBehavior(Item))
SpeedBooster.sprite = 'speed-booster'
return SpeedBooster
