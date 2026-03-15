-- renderer/init.lua
local Reconciler = require("react.Reconciler")
local HostConfig = require("renderer.HostConfig")

local ReactSolar2D = {}

local reconcilerInstance = nil

function ReactSolar2D.render(element, container)
    if not reconcilerInstance then
        reconcilerInstance = Reconciler.create(HostConfig)
    end
    reconcilerInstance.render(element, container)
    return reconcilerInstance
end

function ReactSolar2D.unmount(container)
    if reconcilerInstance then
        reconcilerInstance.unmount(container)
        reconcilerInstance = nil
    end
end

function ReactSolar2D.flushUpdates()
    if reconcilerInstance then
        reconcilerInstance.flushUpdates()
    end
end

function ReactSolar2D.startAutoFlush()
    Runtime:addEventListener("enterFrame", function()
        ReactSolar2D.flushUpdates()
    end)
end

return ReactSolar2D
