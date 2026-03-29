-- components/WebView.lua
-- React wrapper for native.newWebView
-- NOTE: native.* objects render above the GL surface and cannot be
-- clipped, masked, or placed inside ScrollView correctly.

local React = require("react")
local ce = React.createElement

local function WebView(props)
    local source = props.source or {}
    local onLoad = props.onLoad
    local onError = props.onError
    local onMessage = props.onMessage
    local style = props.style or {}
    local webViewRef = React.useRef(nil)

    -- Expose imperative methods via ref
    if props.ref and type(props.ref) == "table" then
        props.ref.current = {
            reload = function()
                if webViewRef.current then
                    webViewRef.current:reload()
                end
            end,
            stop = function()
                if webViewRef.current then
                    webViewRef.current:stop()
                end
            end,
            back = function()
                if webViewRef.current then
                    webViewRef.current:back()
                end
            end,
            forward = function()
                if webViewRef.current then
                    webViewRef.current:forward()
                end
            end,
        }
    end

    local viewRef = React.useRef(nil)
    local onViewRef = React.useCallback(function(instance)
        viewRef.current = instance
    end, {})

    React.useEffect(function()
        local view = viewRef.current
        if not view then return end
        if not native or not native.newWebView then return end

        local w = style.width or 300
        local h = style.height or 200

        -- Create native WebView
        -- Position at center of the View (will be repositioned by layout pass)
        local webView = native.newWebView(w / 2, h / 2, w, h)
        webViewRef.current = webView

        -- URL request listener
        local function urlListener(event)
            if event.type == "loaded" then
                if onLoad then
                    onLoad({ url = event.url })
                end
            elseif event.type == "failed" then
                if onError then
                    onError({ url = event.url, errorCode = event.errorCode, errorMessage = event.errorMessage })
                end
            end

            -- JS→Lua message bridge via URL scheme
            if onMessage and event.url then
                local msg = event.url:match("^rn%-message://(.+)")
                if msg then
                    onMessage({ data = msg })
                    return false  -- prevent navigation
                end
            end

            return true
        end
        webView:addEventListener("urlRequest", urlListener)

        -- Load content
        if source.uri then
            webView:request(source.uri)
        elseif source.html then
            -- Inject message bridge JS
            local html = source.html
            if onMessage then
                local bridge = [[<script>
                    window.ReactNativeWebView = {
                        postMessage: function(data) {
                            window.location = 'rn-message://' + encodeURIComponent(data);
                        }
                    };
                </script>]]
                html = html:gsub("</head>", bridge .. "</head>")
                if not html:find("</head>") then
                    html = bridge .. html
                end
            end
            webView:request("data:text/html," .. html)
        end

        -- Store webView on the group for layout positioning
        view._webView = webView

        return function()
            if webView and webView.removeSelf then
                webView:removeSelf()
            end
            webViewRef.current = nil
            if view then view._webView = nil end
        end
    end, { source.uri, source.html })

    return ce("View", {
        style = style,
        ref = onViewRef,
    })
end

return WebView
