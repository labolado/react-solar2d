-- lib/gesture-handler/init.lua
-- Minimal react-native-gesture-handler implementation for Solar2D

local React = require("react")
local ce = React.createElement

local GestureHandler = {}

local State = {
    UNDETERMINED = 0,
    FAILED = 1,
    BEGAN = 2,
    CANCELLED = 3,
    ACTIVE = 4,
    END = 5,
}

local Directions = {
    RIGHT = 1,
    LEFT = 2,
    UP = 4,
    DOWN = 8,
}

local function scheduler(props)
    if props and props._scheduler then
        return props._scheduler
    end
    local s = {}
    function s.setTimeout(fn, delay)
        if timer and timer.performWithDelay then
            local handle = timer.performWithDelay(delay, fn, 1)
            return {
                cancel = function()
                    if timer and timer.cancel and handle then
                        timer.cancel(handle)
                    end
                end,
            }
        end
        -- No timer available, run synchronously
        local cancelled = false
        return {
            cancel = function()
                cancelled = true
            end,
            _fire = function()
                if not cancelled then fn() end
            end,
        }
    end
    return s
end

local function buildEventPayload(ctrl, solarEvent)
    return {
        translationX = ctrl.translationX or 0,
        translationY = ctrl.translationY or 0,
        velocityX = ctrl.velocityX or 0,
        velocityY = ctrl.velocityY or 0,
        absoluteX = solarEvent and solarEvent.x or 0,
        absoluteY = solarEvent and solarEvent.y or 0,
        x = solarEvent and solarEvent.x or 0,
        y = solarEvent and solarEvent.y or 0,
        numberOfPointers = solarEvent and (solarEvent.numTaps or solarEvent.numTouches) or 1,
        state = ctrl.state or State.UNDETERMINED,
    }
end

local function emitHandlerChange(ctrl, state, solarEvent)
    ctrl.state = state
    if ctrl.props and ctrl.props.onHandlerStateChange then
        ctrl.props.onHandlerStateChange({
            nativeEvent = buildEventPayload(ctrl, solarEvent),
            state = state,
        })
    end
end

local function emitGestureEvent(ctrl, solarEvent)
    if ctrl.props and ctrl.props.onGestureEvent then
        ctrl.props.onGestureEvent({
            nativeEvent = buildEventPayload(ctrl, solarEvent),
            state = ctrl.state or State.UNDETERMINED,
        })
    end
end

local function shouldActivate(ctrl, dx, dy)
    local props = ctrl.props or {}
    local threshold = props.minDist or 5
    local ax = props.activeOffsetX or threshold
    local ay = props.activeOffsetY or threshold
    return math.abs(dx) >= ax or math.abs(dy) >= ay
end

local function createPanController(initialProps)
    local ctrl = {
        props = initialProps or {},
        state = State.UNDETERMINED,
        translationX = 0,
        translationY = 0,
        velocityX = 0,
        velocityY = 0,
        _active = false,
        _lastTime = nil,
        _startX = 0,
        _startY = 0,
    }

    function ctrl:updateProps(newProps)
        self.props = newProps or {}
    end

    function ctrl:_reset()
        self.translationX = 0
        self.translationY = 0
        self.velocityX = 0
        self.velocityY = 0
        self._active = false
        self._lastTime = nil
        self.state = State.UNDETERMINED
    end

    function ctrl:onTouchStart(event)
        if self.props.enabled == false then return end
        self._startX = event.x or 0
        self._startY = event.y or 0
        local now = (system and system.getTimer and system.getTimer()) or 0
        self._lastTime = event.time or now
        self.translationX = 0
        self.translationY = 0
        self.velocityX = 0
        self.velocityY = 0
        emitHandlerChange(self, State.BEGAN, event)
    end

    function ctrl:onTouchMove(event)
        if self.props.enabled == false then return end
        local dx = (event.x or 0) - self._startX
        local dy = (event.y or 0) - self._startY
        local now = event.time or (system and system.getTimer and system.getTimer()) or 0
        local dt = now - (self._lastTime or now)
        if dt <= 0 then dt = 1 end
        self.translationX = dx
        self.translationY = dy
        self.velocityX = (dx - (self._prevX or 0)) / dt * 1000
        self.velocityY = (dy - (self._prevY or 0)) / dt * 1000
        self._prevX = dx
        self._prevY = dy
        self._lastTime = now
        if not self._active and shouldActivate(self, dx, dy) then
            self._active = true
            emitHandlerChange(self, State.ACTIVE, event)
        end
        if self._active then
            emitGestureEvent(self, event)
        end
    end

    function ctrl:onTouchEnd(event)
        if self.props.enabled == false then return end
        if self._active then
            emitHandlerChange(self, State.END, event)
        else
            emitHandlerChange(self, State.FAILED, event)
        end
        self:_reset()
    end

    function ctrl:onTouchCancel(event)
        if self._active then
            emitHandlerChange(self, State.CANCELLED, event)
        else
            emitHandlerChange(self, State.FAILED, event)
        end
        self:_reset()
    end

    return ctrl
end

local function createTapController(initialProps)
    local ctrl = {
        props = initialProps or {},
        state = State.UNDETERMINED,
        _startX = 0,
        _startY = 0,
        _startTime = 0,
    }

    function ctrl:updateProps(newProps)
        self.props = newProps or {}
    end

    function ctrl:onTouchStart(event)
        if self.props.enabled == false then return end
        self._startX = event.x or 0
        self._startY = event.y or 0
        local now = (system and system.getTimer and system.getTimer()) or 0
        self._startTime = event.time or now
        emitHandlerChange(self, State.BEGAN, event)
    end

    function ctrl:onTouchMove(event)
        if self.props.enabled == false then return end
        local maxDist = self.props.maxDist or 10
        local dx = math.abs((event.x or 0) - self._startX)
        local dy = math.abs((event.y or 0) - self._startY)
        if dx > maxDist or dy > maxDist then
            emitHandlerChange(self, State.FAILED, event)
            self.state = State.UNDETERMINED
        end
    end

    function ctrl:onTouchEnd(event)
        if self.props.enabled == false then return end
        local current = (system and system.getTimer and system.getTimer()) or 0
        local duration = (event.time or current) - self._startTime
        local maxDuration = self.props.maxDurationMs or 500
        local dx = math.abs((event.x or 0) - self._startX)
        local dy = math.abs((event.y or 0) - self._startY)
        local maxDist = self.props.maxDist or 10
        if duration <= maxDuration and dx <= maxDist and dy <= maxDist then
            emitHandlerChange(self, State.ACTIVE, event)
            if self.props.onActivated then
                self.props.onActivated({ nativeEvent = buildEventPayload(self, event), state = State.ACTIVE })
            end
            emitHandlerChange(self, State.END, event)
        else
            emitHandlerChange(self, State.FAILED, event)
        end
        self.state = State.UNDETERMINED
    end

    function ctrl:onTouchCancel(event)
        emitHandlerChange(self, State.CANCELLED, event)
        self.state = State.UNDETERMINED
    end

    return ctrl
end

local function createLongPressController(initialProps)
    local ctrl = {
        props = initialProps or {},
        state = State.UNDETERMINED,
        _startX = 0,
        _startY = 0,
        _timerHandle = nil,
        _activated = false,
    }

    function ctrl:updateProps(newProps)
        self.props = newProps or {}
    end

    function ctrl:_clearTimer()
        if self._timerHandle and self._timerHandle.cancel then
            self._timerHandle.cancel()
        elseif self._timerHandle and self._timerHandle._fire then
            -- manual scheduler used in tests
            self._timerHandle._fire = nil
        end
        self._timerHandle = nil
    end

    function ctrl:_scheduleActivation(event)
        local delay = self.props.minDurationMs or 600
        local sched = scheduler(self.props)
        self._timerHandle = sched.setTimeout(function()
            self._timerHandle = nil
            self._activated = true
            emitHandlerChange(self, State.ACTIVE, event)
            if self.props.onActivated then
                self.props.onActivated({ nativeEvent = buildEventPayload(self, event), state = State.ACTIVE })
            end
        end, delay)
    end

    function ctrl:onTouchStart(event)
        if self.props.enabled == false then return end
        self._startX = event.x or 0
        self._startY = event.y or 0
        self._activated = false
        emitHandlerChange(self, State.BEGAN, event)
        self:_scheduleActivation(event)
    end

    function ctrl:onTouchMove(event)
        if self.props.enabled == false then return end
        local maxDist = self.props.maxDist or 12
        local dx = math.abs((event.x or 0) - self._startX)
        local dy = math.abs((event.y or 0) - self._startY)
        if dx > maxDist or dy > maxDist then
            self:_clearTimer()
            emitHandlerChange(self, State.FAILED, event)
        end
    end

    function ctrl:onTouchEnd(event)
        if self.props.enabled == false then return end
        self:_clearTimer()
        if self._activated then
            emitHandlerChange(self, State.END, event)
        else
            emitHandlerChange(self, State.FAILED, event)
        end
        self._activated = false
    end

    function ctrl:onTouchCancel(event)
        self:_clearTimer()
        emitHandlerChange(self, State.CANCELLED, event)
        self._activated = false
    end

    return ctrl
end

local function useController(factory, props)
    local ref = React.useRef()
    if not ref.current then
        ref.current = factory(props)
    else
        ref.current:updateProps(props)
    end
    return ref.current
end

function GestureHandler.GestureHandlerRootView(props)
    return ce("View", { style = props and props.style }, props and props.children)
end

function GestureHandler.PanGestureHandler(props)
    local controller = useController(createPanController, props or {})
    local style = props and props.style
    return ce("View", {
        style = style,
        onTouchStart = function(event) controller:onTouchStart(event) end,
        onTouchMove = function(event) controller:onTouchMove(event) end,
        onTouchEnd = function(event) controller:onTouchEnd(event) end,
        onTouchCancel = function(event) controller:onTouchCancel(event) end,
    }, props and props.children)
end

function GestureHandler.TapGestureHandler(props)
    local controller = useController(createTapController, props or {})
    return ce("View", {
        style = props and props.style,
        onTouchStart = function(event) controller:onTouchStart(event) end,
        onTouchMove = function(event) controller:onTouchMove(event) end,
        onTouchEnd = function(event) controller:onTouchEnd(event) end,
        onTouchCancel = function(event) controller:onTouchCancel(event) end,
    }, props and props.children)
end

function GestureHandler.LongPressGestureHandler(props)
    local controller = useController(createLongPressController, props or {})
    return ce("View", {
        style = props and props.style,
        onTouchStart = function(event) controller:onTouchStart(event) end,
        onTouchMove = function(event) controller:onTouchMove(event) end,
        onTouchEnd = function(event) controller:onTouchEnd(event) end,
        onTouchCancel = function(event) controller:onTouchCancel(event) end,
    }, props and props.children)
end

GestureHandler.State = State
GestureHandler.Directions = Directions
GestureHandler._internal = {
    createPanController = createPanController,
    createTapController = createTapController,
    createLongPressController = createLongPressController,
}

return GestureHandler
