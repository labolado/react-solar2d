-- components/RefreshControl.lua
-- Pull-to-refresh control for ScrollView.
-- In React Native, this is used inside ScrollView/FlatList's refreshControl prop.
-- In Solar2D, we integrate with ScrollView's onRefresh mechanism.
local React = require("react")
local createElement = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local function RefreshControl(props)
    local refreshing = props.refreshing or false
    local onRefresh = props.onRefresh
    local tintColor = props.tintColor or "#999999"
    local title = props.title
    local titleColor = props.titleColor or "#999999"
    local progressViewOffset = props.progressViewOffset or 0

    -- Rotation angle for spinner animation (0 to 360)
    local rotation, setRotation = useState(0)
    local timerRef = useRef(nil)

    -- Animate rotation when refreshing state changes
    useEffect(function()
        if refreshing then
            -- Start continuous rotation animation
            local function rotateStep()
                if not refreshing then return end
                setRotation(function(prev)
                    return (prev + 30) % 360
                end)
                -- Schedule next rotation
                if timer and timer.performWithDelay then
                    timerRef.current = timer.performWithDelay(50, rotateStep, 1)
                end
            end
            -- Start the animation loop
            if timer and timer.performWithDelay then
                timerRef.current = timer.performWithDelay(50, rotateStep, 1)
            end
        else
            -- Stop animation
            if timerRef.current and timer.cancel then
                timer.cancel(timerRef.current)
                timerRef.current = nil
            end
            setRotation(0)
        end

        -- Cleanup on unmount or when refreshing changes
        return function()
            if timerRef.current and timer.cancel then
                timer.cancel(timerRef.current)
                timerRef.current = nil
            end
        end
    end, { refreshing })

    -- Spinner component using rotating dots
    local spinnerSize = 40
    local dotSize = spinnerSize / 4
    local dotRadius = dotSize / 2

    -- Calculate dot positions in a circle with rotation
    local function getDotPosition(index, total, radius, rotationAngle)
        local angle = (index - 1) * (2 * math.pi / total) - (math.pi / 2) + math.rad(rotationAngle or 0)
        return {
            x = radius * math.cos(angle) + spinnerSize / 2 - dotRadius,
            y = radius * math.sin(angle) + spinnerSize / 2 - dotRadius,
        }
    end

    local dots = {}
    local numDots = 8
    local radius = spinnerSize / 2 - dotSize

    for i = 1, numDots do
        local pos = getDotPosition(i, numDots, radius, rotation)
        local opacity = 0.2 + (0.8 * ((i - 1) / (numDots - 1)))
        dots[#dots + 1] = createElement("View", {
            key = "dot_" .. i,
            style = {
                position = "absolute",
                left = pos.x,
                top = pos.y + progressViewOffset,
                width = dotSize,
                height = dotSize,
                borderRadius = dotRadius,
                backgroundColor = tintColor,
                opacity = opacity,
            },
        })
    end

    -- Title text if provided
    local titleElement = nil
    if title then
        titleElement = createElement("Text", {
            key = "title",
            style = {
                fontSize = 12,
                color = titleColor,
                marginTop = 8,
            },
        }, title)
    end

    return createElement("View", {
        style = {
            flexDirection = "column",
            justifyContent = "center",
            alignItems = "center",
            height = 60,
            opacity = refreshing and 1 or 0.5,
        },
    },
        createElement("View", {
            style = {
                width = spinnerSize,
                height = spinnerSize + progressViewOffset,
            },
        }, dots),
        titleElement
    )
end

return RefreshControl
