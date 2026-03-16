# Design Constraints

> **Version:** 1.0 | **Date:** 2026-03-15 | **Status:** Active

## Must Have

1. **API 100% aligned with React Native** — naming, parameters, style properties
2. **Pure Lua implementation** — no native plugins, no Solar2D source modifications
3. **RN pure-JS plugin compatibility** — change imports, minimal other changes
4. **AI-friendly** — AI can generate standard RN code that runs with near-zero modification
5. **Non-invasive** — integrates alongside existing labo_* game code, no conflicts
6. **Performance** — UI layer must not impact game rendering (60fps)

## Nice to Have

1. Animated API compatible with RN's Animated
2. Hot-reload friendly (re-render without restart)
3. DevTools integration (component tree inspector)

## Non-Goals

1. Not replacing Solar2D's game rendering
2. Not a web browser / WebView
3. Not supporting RN native modules (Java/ObjC bridges)
4. Not a full React 18 implementation (React 17 is sufficient)

## Key References

| Resource | Purpose |
|---|---|
| [jsdotlua/react-lua](https://github.com/jsdotlua/react-lua) | React core, hooks, reconciler |
| [grilme99/Flow](https://github.com/grilme99/Flow) | Flexbox layout engine (Yoga port) |
| React Native StyleSheet docs | API surface to match |
| Solar2D API docs | Rendering target |

## Target Projects

55+ labo_* Solar2D games at /path/to/home
- labo_ball_hero2 (96K lines, 451 files)
- labo_papercut_car (62K lines, 45+ shaders)
- labo_engineering_vehicle (55K lines, 38 machine types)
- ... and 52 more
