local tortusBase = require "tortus.tortusBase"

local navModule = {}



---Returns the turtle's position
---@return table
function navModule.getPos()
    tortusBase.updatePosition()
    return tortusBase.cache.position.handle
end



---Returns the turtle's cardinal direction
---@return string
function navModule.getFacing()
    return tortusBase.cache.direction
end



--------------------------------------------------
--[[
    internal logic for most movement functions
]]
local function internalMovement(count, direction, reverse)
    count = count or 1
    local is_success
    local blocksMoved = count

    if count > tortusBase.turtle.getFuelLevel() then
        return false, 0
    end

    tortusBase.updatePosition()

    for i = 1, count do
        is_success = tortusBase.turtle[direction]()
        if not is_success then
            blocksMoved = i - 1
            break
        else
            tortusBase.cache.lastCardinalMovement = tortusBase.cache.direction
            tortusBase.cache.movementLog[#tortusBase.cache.movementLog.handle + 1] = {
                move = direction,
                reverse = reverse
            }
        end
    end
    return is_success, blocksMoved
end
--



---Moves the turtle forward.
---@param count number
---@return boolean
---@return number
function navModule.forward(count)
    return internalMovement(count, "forward", "back")
end


---Moves the turtle backward.
---@param count number
---@return boolean
---@return number
function navModule.back(count)
    return internalMovement(count, "back", "forward")
end



---Moves the turtle upward.
---@param count number
---@return boolean
---@return number
function navModule.up(count)
    internalMovement(count, "up", "down")
end



---Moves the turtle downward.
---@param count number
---@return boolean
---@return number
function navModule.down(count)
    internalMovement(count, "down", "up")
end



---Turns the turtle left once.
function navModule.turnLeft()
    tortusBase.cache.direction = tortusBase.directionLookup[tortusBase.cache.direction].left
    tortusBase.cache.movementLog[#tortusBase.cache.movementLog.handle + 1] = {
        move = "turnLeft",
        reverse = "turnRight"
    }
    return tortusBase.turtle.turnLeft()
end



---Turns the turtle right once.
function navModule.turnRight()
    tortusBase.cache.direction = tortusBase.directionLookup[tortusBase.cache.direction].right
    tortusBase.cache.movementLog[#tortusBase.cache.movementLog.handle + 1] = {
        move = "turnRight",
        reverse = "turnLeft"
    }
    return tortusBase.turtle.turnRight()
end



---Turns the turtle the opposite direction.
function navModule.reverse()
    tortusBase.cache.direction = tortusBase.directionLookup[tortusBase.cache.direction].back
    tortusBase.cache.movementLog[#tortusBase.cache.movementLog.handle + 1] = {
        move = "turnRight",
        reverse = "turnLeft"
    }
    tortusBase.cache.movementLog[#tortusBase.cache.movementLog.handle + 1] = {
        move = "turnRight",
        reverse = "turnLeft"
    }
    tortusBase.turtle.turnRight()
    return tortusBase.turtle.turnRight()
end



--------------------------------------------------
--[[
    internal logic for both strafe functions
]]
local function internalStrafe(firstDir, secDir, count)
        firstDir()
        local is_success, blocksMoved = navModule.forward(count)
        secDir()
        return is_success, blocksMoved
end
--



---Moves the turtle to its left
---@param count number
function navModule.strafeLeft(count)
    return internalStrafe(navModule.turnLeft, navModule.turnRight, count)
end



---Moves the turtle to its right
---@param count number
function navModule.strafeRight(count)
    return internalStrafe(navModule.turnRight, navModule.turnLeft, count)
end



---Undoes any movements made previously by the turtle.
---@param count number
---@return boolean
---@return number
---@return string|nil
function navModule.undoMovement(count)

    local reduceRotations = 0
    local lastRotation = "none"
    local movementLog = {}

    count = count or 1
    if count > #tortusBase.cache.movementLog.handle then
        count = #tortusBase.cache.movementLog.handle
    end

    for i = 1, count do
        movementLog[i] = tortusBase.cache.movementLog.reverse
    end

    local fuelCheck = 0
    for i = 1, count do
        if movementLog[i] ~= "turnLeft" and movementLog[i] ~= "turnRight" then
            fuelCheck = fuelCheck + 1
        end
    end
    if fuelCheck > tortusBase.turtle.getFuelLevel() then
        return false, 0
    end

    for i = 1, count do
        local movement = table.remove(movementLog, #movementLog).reverse
        if reduceRotations > 0 and (movement ~= lastRotation or i == count) then
            if movement == lastRotation then
                reduceRotations = reduceRotations + 1
            end

            local totalRots = reduceRotations % 4
            if totalRots == 3 then
                totalRots = 1
                lastRotation = lastRotation == "turnLeft" and "turnRight" or "turnLeft"
            end

            for _ = 1, totalRots do
                navModule[lastRotation]()
            end

            navModule[lastRotation]()
        end

        if (movement == "turnLeft" or movement == "turnRight") then
            if i < count then
                if lastRotation~=movement then
                    lastRotation = movement
                    reduceRotations = 1
                else
                    reduceRotations = reduceRotations + 1
                end
            elseif reduceRotations == 0 then
                navModule[movement]()
            end
        else
            local is_Success = navModule[movement]()
            reduceRotations = 0
            lastRotation = "none"

            if not is_Success then
                table.insert(movementLog, 1, movement)
                tortusBase.cache.movementLog = movementLog
                return false, i, movement
            end
        end

    end

    tortusBase.cache.movementLog = movementLog
    return true, count
end


---Undoes all movement recorded by the turtle.
---@return boolean
---@return number
---@return string|nil
function navModule.undoAllMovement()
	return navModule.undoMovement(#tortusBase.cache.movementLog.handle)
end



---Clears the turtle's movement history.
function navModule.clearLog()
	tortusBase.cache.movementLog = {}
end



for k, v in next, navModule do
    tortusBase.library[k] = v
end

return navModule