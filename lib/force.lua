local tortusBase = require "tortus.tortusBase"
local navModule = require "tortus.lib.nav"

local forceModule = {}

--------------------------------------------------
--[[
    internal logic for all force move functions except back
]]
local internalMoveForce = function(direction, fnDig, fnAttack, count)
    if count == 0 then
        return true
    end

    local is_success, distanceMoved
    count = count or 1

    if tortusBase.turtle.getFuelLevel() >= count then

        repeat
            is_success, distanceMoved = direction(count)
            if distanceMoved then
                count = count - distanceMoved
                fnDig()
                fnAttack()
            end
        until is_success
        return true
    end

    return false
end
--



---Moves forward without anything stopping it except low fuel.
---@param count number
---@return boolean
function forceModule.forwardForce(count)
    return internalMoveForce(navModule.forward, tortusBase.turtle.dig, tortusBase.turtle.attack, count)
end



---Moves backward without anything stopping it except low fuel.
---@param count number
---@return boolean
function forceModule.backForce(count)
    if count == 0 then
        return true
    end

    local _, distanceMoved
    count = count or 1

    if tortusBase.turtle.getFuelLevel() >= count then

        _, distanceMoved = tortusBase.turtle.back(count)
        if distanceMoved then
            tortusBase.chain.reverse()
                            .dig()
                            .attack()
            internalMoveForce(navModule.forward, tortusBase.turtle.dig, tortusBase.turtle.attack, count - distanceMoved)
        end
        navModule.reverse()
        return true
    end

    return false
end



---Moves upward without anything stopping it except low fuel.
---@param count number
---@return boolean
function forceModule.upForce(count)
    return internalMoveForce(navModule.up, tortusBase.turtle.digUp, tortusBase.turtle.attackUp, count)
end



---Moves downward without anything stopping it except low fuel.
---@param count number
---@return boolean
function forceModule.downForce(count)
    return internalMoveForce(navModule.down, tortusBase.turtle.digDown, tortusBase.turtle.attackDown, count)
end



---Moves left without anything stopping it except low fuel.
---@param count number
---@return boolean
function forceModule.strafeRightForce(count)
    turnRight()
    local is_success = internalMoveForce(navModule.forward, tortusBase.turtle.dig, tortusBase.turtle.attack, count)
    turnLeft()
    return is_success
end



---Moves right without anything stopping it except low fuel.
---@param count number
---@return boolean
function forceModule.strafeLeftForce(count)
    turnLeft()
    local is_success = internalMoveForce(navModule.forward, tortusBase.turtle.dig, tortusBase.turtle.attack, count)
    turnRight()
    return is_success
end



local movementTranslation = {
    up = "Up",
    down = "Down",
    forward = "",
}

---Undoes previous movements without anything stopping it except low fuel.
---@param count number
---@return boolean
function forceModule.undoMovementForce(count)

    local is_success, distanceMoved, lastMove
    repeat
        is_success, distanceMoved, lastMove = navModule.undoMovement(count)
        count = count - distanceMoved
        if not is_success then
            if not lastMove then
                return false
            elseif lastMove == "back" then
                tortusBase.chain.reverse()
                                .dig()
                                .attack()
                                .reverse()
            else
                tortusBase.turtle["dig"..movementTranslation[lastMove]]()
                tortusBase.turtle["attack"..movementTranslation[lastMove]]()
            end
        end
    until is_success
end



---Undoes all previous movements without anything stopping it except low fuel.
---@return boolean
function forceModule.undoAllMovementForce()
	return undoForce(#tortusBase.cache.movementLog.handle)
end



for k, v in next, forceModule do
    tortusBase.library[k] = v
end

return forceModule