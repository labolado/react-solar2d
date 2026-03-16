-- animated/init.lua
-- Animated API wrapping Solar2D transition.to
local Animated = {}

-- AnimatedValue class
local AnimatedValue = {}
AnimatedValue.__index = AnimatedValue

function Animated.Value(initial)
    return setmetatable({
        _value = initial or 0,
        _listeners = {},
        _animation = nil,
    }, AnimatedValue)
end

function AnimatedValue:getValue()
    return self._value
end

function AnimatedValue:setValue(v)
    self._value = v
    for _, listener in ipairs(self._listeners) do
        listener({ value = v })
    end
end

function AnimatedValue:addListener(callback)
    self._listeners[#self._listeners + 1] = callback
    return #self._listeners
end

function AnimatedValue:removeListener(id)
    if id and self._listeners[id] then
        table.remove(self._listeners, id)
    end
end

function AnimatedValue:stopAnimation(callback)
    if self._animation then
        if transition and transition.cancel then
            transition.cancel(self._animation)
        end
        self._animation = nil
    end
    if callback then callback(self._value) end
end

-- Animated.timing — drive AnimatedValue via Solar2D transition.to
function Animated.timing(value, config)
    local anim = {}
    local toValue = config.toValue
    local duration = config.duration or 300
    local easingFn = config.easing
    local delay = config.delay or 0
    anim._value = value  -- expose for loop reset

    function anim.start(callback)
        if transition and transition.to then
            local proxy = { val = value:getValue() }
            value._animation = transition.to(proxy, {
                time = duration,
                delay = delay,
                val = toValue,
                transition = easingFn,
                onComplete = function()
                    value:setValue(toValue)
                    value._animation = nil
                    if callback then callback({ finished = true }) end
                end,
            })
            -- Sync proxy to AnimatedValue each frame
            local function sync()
                if value._animation then
                    value:setValue(proxy.val)
                else
                    Runtime:removeEventListener("enterFrame", sync)
                end
            end
            Runtime:addEventListener("enterFrame", sync)
        else
            -- Non-Solar2D: jump to final value
            value:setValue(toValue)
            if callback then callback({ finished = true }) end
        end
    end

    function anim.stop()
        value:stopAnimation()
    end

    return anim
end

-- Animated.spring — simplified using elastic easing
function Animated.spring(value, config)
    local newConfig = {
        toValue = config.toValue,
        duration = config.duration or 500,
        easing = (easing and easing.outElastic) or nil,
    }
    return Animated.timing(value, newConfig)
end

-- Animated.sequence — run animations in order
function Animated.sequence(animations)
    local anim = {}
    anim._children = animations  -- expose for loop reset
    function anim.start(callback)
        local index = 1
        local function next()
            if index > #animations then
                if callback then callback({ finished = true }) end
                return
            end
            animations[index].start(function()
                index = index + 1
                next()
            end)
        end
        next()
    end
    function anim.stop()
        for _, a in ipairs(animations) do
            if a.stop then a.stop() end
        end
    end
    return anim
end

-- Animated.parallel — run animations simultaneously
function Animated.parallel(animations)
    local anim = {}
    anim._children = animations  -- expose for loop reset
    function anim.start(callback)
        local remaining = #animations
        if remaining == 0 then
            if callback then callback({ finished = true }) end
            return
        end
        for _, a in ipairs(animations) do
            a.start(function()
                remaining = remaining - 1
                if remaining == 0 and callback then
                    callback({ finished = true })
                end
            end)
        end
    end
    function anim.stop()
        for _, a in ipairs(animations) do
            if a.stop then a.stop() end
        end
    end
    return anim
end

-- Collect all AnimatedValues from an animation tree (timing, sequence, parallel)
local function collectValues(animation)
    local vals = {}
    if animation._value then
        vals[#vals + 1] = animation._value
    end
    if animation._children then
        for _, child in ipairs(animation._children) do
            for _, v in ipairs(collectValues(child)) do
                vals[#vals + 1] = v
            end
        end
    end
    return vals
end

-- Animated.loop — repeat an animation
function Animated.loop(animation, config)
    local iterations = (config and config.iterations) or -1 -- -1 = infinite
    local anim = {}
    local count = 0
    local stopped = false

    function anim.start(callback)
        stopped = false
        count = 0
        -- Snapshot initial values on first start
        local values = collectValues(animation)
        local initials = {}
        for i, v in ipairs(values) do
            initials[i] = v:getValue()
        end

        local function runOnce()
            if stopped then return end
            -- Reset all values to initial state before each iteration
            for i, v in ipairs(values) do
                v:setValue(initials[i])
            end
            animation.start(function()
                count = count + 1
                if iterations > 0 and count >= iterations then
                    if callback then callback({ finished = true }) end
                else
                    runOnce()
                end
            end)
        end
        runOnce()
    end

    function anim.stop()
        stopped = true
        animation.stop()
    end

    return anim
end

-- Animated component markers (HostConfig recognizes these)
Animated.View = "Animated.View"
Animated.Text = "Animated.Text"
Animated.Image = "Animated.Image"

return Animated
