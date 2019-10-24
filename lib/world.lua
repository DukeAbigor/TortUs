local tortusBase = require "tortus.tortusBase"

local worldModule = {}



--------------------------------------------------
--[[
    internal logic for all place functions
]]
local function internalPlace(direction, text, slot)
    if slot and not select(slot) then
        return false
    end
	return text and tortusBase.turtle[direction](text) or tortusBase.turtle[direction]()
end
--------------------------------------------------



---Attempts to place a block in front of the turtle
---@param text string|nil
---@param slot number|string|nil
---@return boolean
function worldModule.place(text, slot)
    return internalPlace("place", text, slot)
end



---Attempts to place a block above the turtle
---@param text string|nil
---@param slot number|string|nil
---@return boolean
function worldModule.placeUp(text, slot)
    return internalPlace("placeUp", text, slot)
end



---Attempts to place a block below the turtle
---@param text string|nil
---@param slot number|string|nil
---@return boolean
function worldModule.placeDown(text, slot)
    return internalPlace("placeDown", text, slot)
end



for k, v in next, worldModule do
    tortusBase.library[k] = v
end

return worldModule