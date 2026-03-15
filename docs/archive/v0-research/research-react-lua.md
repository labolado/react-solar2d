# Research: react-lua (Roblox)

Source: https://github.com/jsdotlua/react-lua

## Overview

Complete port of React 17 to Luau. Monorepo with packages:

| Package | Role |
|---|---|
| **react** | createElement, hooks, component model |
| **react-reconciler** | Full Fiber architecture (not simplified) |
| **react-roblox** | Host renderer for Roblox Instances |
| **scheduler** | Priority-based cooperative scheduling |
| **shared** | Shared utilities |
| **roact-compat** | Migration wrapper from legacy Roact |

## Reconciler: Full Fiber

- Faithful port of React 17 Fiber reconciler
- Two-phase: render (beginWork/diff) → commit (apply mutations)
- Fiber nodes with memoizedState, pendingProps, child, sibling, return
- Supports incremental/interruptible rendering
- Priority lanes via Scheduler

## Hooks Implementation

Stored as linked list on fiber's memoizedState. Implemented:
- useState, useEffect, useContext, useRef, useMemo, useCallback
- useReducer, useLayoutEffect, useImperativeHandle
- Lua-specific: useState returns two values (not array)
- Roblox-specific: useBinding (lightweight observable for animations)

## Host Renderer Pattern

react-roblox defines how to:
- createInstance → Instance.new("Frame") etc.
- updateInstance → set properties on Roblox instances
- appendChild/removeChild → Parent property manipulation
- commitMount/commitUpdate → apply changes

**This is exactly what we need to replicate for Solar2D.**

## What react-lua Does NOT Have

- No StyleSheet system
- No Flexbox layout engine
- No CSS-like styling
- No UI component library (View, Text, Image, etc.)

These are provided by Roblox's native UI system (UDim2, UIListLayout, etc.)

## Key Takeaway

We can reference react-lua for:
- React core architecture
- Hooks implementation pattern
- Reconciler strategy

We must build ourselves:
- Solar2D host renderer
- Flexbox layout engine
- StyleSheet + CSS property mapping
- UI component library
