# Research: Existing UI Patterns in labo_* Projects

## Component Architecture

All projects share a common `lib/ui/component` system:
- `Component.add(name, target, options)` — attach behavior to display objects
- Enable/disable lifecycle: `Component.enable()`, `Component.disable()`, `Component.remove()`
- Components stored in `target._components` dictionary

## Key Existing Components

| Component | File | Description |
|-----------|------|-------------|
| Button | `button.lua`, `dmc_button.lua` | Signal-based, scale feedback (overScale=0.96), touch region |
| Scrollable | `scrollable.lua` | H/V scroll, momentum physics, lazy loading |
| Tap | `tap.lua` | Precise tap detection with region bounds |
| Slider | `slider.lua`, `slider_stick.lua` | Slider controls |
| Joystick | `joystick.lua` | Virtual joystick |
| Draggable | `draggable.lua` | Drag-and-drop |
| PinchZoomRotate | `pinch_zoom_rotate.lua` | Gesture handling |
| TabControl | `tab_control.lua` | Tab switching |

## View/Layout Patterns

**PagerSlideView** — Grid pagination with cell rendering callback:
```lua
cellRender(card, layout)  -- card: {id, x, y}, layout: {getCurrentPageNo(), getTotalPageNum()}
```

**DragableScrollView** — Scrollable list with drag-to-create

## Button Factory

```lua
ui.newButton{
    default = image("/buttons/musicon.png"),
    overScale = 0.95,
    virtualTouchRange = {128, 10},
    onEvent = function(e) ... end
}
```

Also: `widget.newEasyButton()`, `widget.newSwitchButton()`, `widget.newNeedToConfirmButton()`

## Modal/Popup Pattern

- Display group as container
- Semi-transparent rect as touch blocker
- Transition animations on open/close
- Singleton pattern for loading overlays

## Theming

Theme files (`scene_build/theme*.lua`) define:
- Background config, material definitions, colors, textures
- Button asset directories
- Platform-specific assets
- 8+ theme variants per project

## Event System

- **Signals**: `self.signals.emit(SIG_NAME, data)` / `self:sigRegister(SIG_NAME, cb)`
- **Touch phases**: "began", "moved", "ended", "cancelled"
- **Focus**: `display.getCurrentStage():setFocus(target, event.id)`

## Integration Insights

| Existing Pattern | React Equivalent |
|---|---|
| Component.add(name, target, opts) | `<Component {...props} />` |
| options dict | React props |
| onEvent callback | onPress/onChange handlers |
| pressed/isFocus state | useState hooks |
| Theme tables | Context providers |
| Signal system | Custom hooks / event emitters |
| PagerSlideView cell render | FlatList renderItem |

## Key Takeaway

The existing component system is mature but imperative. The React framework should:
1. Wrap existing patterns declaratively
2. Keep touch/focus management compatible
3. Support existing theme system via Context
4. Allow gradual migration — new React UI alongside old imperative UI
