#!/usr/bin/env lua
-- run_tests.lua — Unified test runner for react-solar2d
-- Usage: lua run_tests.lua [pattern]
-- Examples:
--   lua run_tests.lua           # run all tests
--   lua run_tests.lua hooks     # run only test files matching "hooks"
--   lua run_tests.lua renderer  # run only renderer tests

package.path = "./?.lua;./?/init.lua;" .. package.path

local pattern = arg[1] -- optional filter

-- Collect all test files
local testFiles = {
    "tests/react/test_createElement.lua",
    "tests/react/test_hooks.lua",
    "tests/react/test_hooks_nil.lua",
    "tests/react/test_reconciler.lua",
    "tests/react/test_new_hooks.lua",
    "tests/style/test_processColor.lua",
    "tests/style/test_stylesheet.lua",
    "tests/renderer/test_hostConfig.lua",
    "tests/renderer/test_hostConfig_styles.lua",
    "tests/renderer/test_hostConfig_new.lua",
    "tests/components/test_view.lua",
    "tests/components/test_text.lua",
    "tests/components/test_scrollview.lua",
    "tests/components/test_flatlist.lua",
    "tests/components/test_textinput.lua",
    "tests/components/test_window_calc.lua",
    "tests/components/test_pressable.lua",
    "tests/components/test_modal.lua",
    "tests/components/test_sectionlist.lua",
    "tests/components/test_refreshcontrol.lua",
    "tests/components/test_keyboard_avoiding.lua",
    "tests/components/test_safe_area.lua",
    "tests/lib/test_gesture_handler.lua",
    "tests/lib/test_linear_gradient.lua",
    "tests/react/test_context.lua",
    "tests/navigation/test_state.lua",
    "tests/navigation/test_stack.lua",
    "tests/navigation/test_tab.lua",
    "tests/navigation/test_drawer.lua",
    "tests/navigation/test_deeplink.lua",
    "tests/integration/test_full_render.lua",
    "tests/infra/test_test_server.lua",
    "tests/components/test_nested_scrollview.lua",
    "tests/lib/test_datetime_picker.lua",
    "tests/react/test_nil_children.lua",
}

-- Filter if pattern given
local filesToRun = {}
for _, f in ipairs(testFiles) do
    if not pattern or f:find(pattern, 1, true) then
        table.insert(filesToRun, f)
    end
end

local totalPassed, totalFailed, totalFiles = 0, 0, 0
local failedFiles = {}

for _, file in ipairs(filesToRun) do
    -- Each test file runs in a subprocess to avoid global state leaks
    local cmd = string.format('lua "%s" 2>&1', file)
    local handle = io.popen(cmd)
    local output = handle:read("*a")
    local ok, _, exitCode = handle:close()

    -- Parse results from output
    local passed, failed = output:match("(%d+) passed, (%d+) failed")
    passed = tonumber(passed) or 0
    failed = tonumber(failed) or 0

    totalPassed = totalPassed + passed
    totalFailed = totalFailed + failed
    totalFiles = totalFiles + 1

    if failed > 0 then
        table.insert(failedFiles, file)
        -- Show full output for failing tests
        print(output)
    else
        -- One-line summary for passing suites
        print(string.format("  PASS  %s (%d tests)", file, passed))
    end
end

print(string.format("\n========================================"))
print(string.format("  Total: %d passed, %d failed (%d files)", totalPassed, totalFailed, totalFiles))
print(string.format("========================================"))

if #failedFiles > 0 then
    print("\nFailing files:")
    for _, f in ipairs(failedFiles) do
        print("  - " .. f)
    end
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
