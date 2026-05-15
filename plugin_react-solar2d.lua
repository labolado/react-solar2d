-- Bootstrap entry point for Solar2D plugin system.
-- Solar2D loads this file when require("plugin.react-solar2d") is called.
-- It adds the plugin root to package.path, then loads the main framework.
do
    local info = debug.getinfo(1, "S")
    local dir = info.source:match("^@(.+/)")
    if dir and not package.path:find(dir, 1, true) then
        package.path = dir .. "?.lua;" .. dir .. "?/init.lua;" .. package.path
    end
end
return require("react_solar2d")
