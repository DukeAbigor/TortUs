--Get out early if not a turtle
if not turtle then
	error("Not a turtle")
end

local tortusBase = require "tortus.tortusBase"
require "tortus.lib.inv"
require "tortus.lib.nav"
require "tortus.lib.world"
require "tortus.lib.force"


for k, v in next, tortusBase.library do
	_G.turtle[k] = v
end