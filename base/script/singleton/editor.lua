-- create once
local modio = require 'base.script.singleton.modio'
local Editor = modio:require 'script.singleton.class.editor'
local editor = Editor()
-- return a getter
-- why a getter?  in case the value needs to be false/nil
-- to return that directly would tell package.loader to reload the file every time it was require'd
return function() return editor end
