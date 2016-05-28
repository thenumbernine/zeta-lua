local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'
local crystalItemBehavior = require 'zeta.script.obj.crystalitem'
local WallJump = class(crystalItemBehavior(Item))
WallJump.sprite = 'walljump'
return WallJump
