# Research: Lua Flexbox Implementations

## Top Candidate: Flow (grilme99/Flow)

- https://github.com/grilme99/Flow
- Lua port of Typeflex (TS port of Meta's Yoga)
- Created by a Roblox engineer who works on React Luau
- Auto-generates tests from HTML fixtures rendered in Chrome
- High-fidelity flexbox spec compliance

### Supported Properties
- flexDirection (row, column, row-reverse, column-reverse)
- justifyContent (flex-start, center, flex-end, space-between, space-around, space-evenly)
- alignItems / alignSelf (flex-start, center, flex-end, stretch, baseline)
- flexWrap (nowrap, wrap, wrap-reverse)
- flex, flexGrow, flexShrink, flexBasis
- width, height, minWidth, maxWidth, minHeight, maxHeight
- padding (all sides), margin (all sides)
- gap, rowGap, columnGap
- position (relative, absolute)
- overflow

### Why This Is Good for Us
- Pure Lua (Luau compatible, minor syntax differences)
- Well-tested against Chrome rendering
- Yoga-compatible algorithm
- Can be adapted from Luau → standard Lua 5.1 (Solar2D)

## Other Options

| Project | Notes |
|---|---|
| FlexLove (mikefreno) | For LOVE2D, less complete |
| luapower/ui | General Lua UI, flexbox-like but not spec-compliant |
| Playout | For Playdate console, limited |

## Decision

Use Flow as primary reference/base for our Flexbox engine. Adapt from Luau to Lua 5.1.
