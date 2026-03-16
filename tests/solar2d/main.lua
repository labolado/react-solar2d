-- tests/solar2d/main.lua
-- Test router: reads .route file to decide which test to run
-- Usage:
--   echo "quiz" > tests/solar2d/.route   → runs test_quiz.lua
--   echo "all" > tests/solar2d/.route    → runs all unit tests
--   (no .route file)                     → runs all unit tests

local path = system.pathForFile("main.lua"):gsub("tests/solar2d/main.lua$", "")
package.path = path .. "?.lua;" .. path .. "?/init.lua;" .. package.path

-- Read route
local route = "all"
local routeFile = io.open(system.pathForFile(".route", system.ResourceDirectory) or "", "r")
if routeFile then
    route = routeFile:read("*l") or "all"
    routeFile:close()
end

print("[TEST ROUTER] route = " .. route)

-- Route to specific test file
if route == "quiz" then
    dofile(system.pathForFile("test_quiz.lua", system.ResourceDirectory))
    return
end

-- Default: run all unit tests (the original test suite)
dofile(system.pathForFile("test_all.lua", system.ResourceDirectory))
