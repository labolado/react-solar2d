# Research: Solar2D Display API for UI Rendering

## Display Object Creation

| Method | Use Case |
|--------|----------|
| `display.newRect(parent, x, y, w, h)` | View background |
| `display.newRoundedRect(parent, x, y, w, h, r)` | View with borderRadius |
| `display.newText(options)` | Text component |
| `display.newImage(parent, file, x, y)` | Image component |
| `display.newImageRect(parent, file, w, h)` | Sized image |
| `display.newGroup()` | View container (no clipping, unlimited nesting) |
| `display.newContainer(parent, w, h)` | View with overflow:hidden (3-mask nesting limit) |
| `display.newCircle(parent, x, y, r)` | Circle shapes |

## Common Properties

### Position & Transform
- x, y, width, height, rotation
- xScale, yScale
- anchorX, anchorY (default 0.5 center — we set to 0,0 for layout)

### Appearance
- alpha (0-1, maps to opacity)
- isVisible (maps to display: none)
- blendMode ("normal", "add", "multiply", "screen")

### Styling (ShapeObject)
- `setFillColor(r, g, b, a)` — values 0-1
- `setStrokeColor(r, g, b, a)`
- `strokeWidth`
- `fill = { type="gradient", color1={r,g,b}, color2={r,g,b}, direction="down" }`

## Events

### Touch
```lua
object:addEventListener("touch", function(event)
    -- event.phase: "began", "moved", "ended", "cancelled"
    -- event.x, event.y, event.xStart, event.yStart
    -- display.currentStage:setFocus(target) for capture
    return true -- stops propagation
end)
```

### Tap
```lua
object:addEventListener("tap", function(event)
    -- event.numTaps for double-tap
    return true
end)
```

## Group Methods
- `group:insert([index,] child)` — add child
- `group:remove(indexOrChild)` — remove child
- `group.numChildren` — child count
- `group[i]` — access by index (1-based)

## Transition API
```lua
transition.to(object, {
    time = 500, delay = 0,
    x, y, alpha, rotation, xScale, yScale, width, height,
    transition = easing.outQuad,
    onComplete = fn,
})
```

41 easing functions available.

## Widget Library
- widget.newScrollView — scrollable container
- widget.newTableView — virtual list with row recycling
- widget.newButton — label/image button

## CSS → Solar2D Mapping Summary

| CSS Property | Solar2D Implementation |
|---|---|
| backgroundColor | setFillColor() on newRect/newRoundedRect |
| borderRadius | newRoundedRect(cornerRadius) |
| borderWidth/Color | strokeWidth + setStrokeColor() |
| opacity | alpha |
| display: none | isVisible = false |
| overflow: hidden | newContainer (mask-based clipping) |
| transform: scale | xScale, yScale |
| transform: rotate | rotation |
| transition | transition.to() |
| boxShadow | extra rect behind with offset + alpha |
| gradient | fill = { type="gradient" } |
| zIndex | group insertion order / toFront()/toBack() |
