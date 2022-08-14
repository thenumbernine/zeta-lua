#!/usr/bin/env luajit
local os = require 'ext.os'
local Image = require 'image'
for dir in os.listdir'.' do
	if os.isdir(dir) then	-- this will error if it fails ...
		for f in os.listdir(dir) do
			if f:match'%.png$' then
				local fn = dir..'/'..f
				local image = Image(fn)
				local w, h = image:size()
				image = image:resize(w/2, h/2)
				image:save(fn)
				print(fn, image:size())
			end
		end
	end
end
