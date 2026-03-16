-- examples/NewsApp.lua
-- Modern Tech News Reader — premium design, not HN clone
local React = require("react")
local json = require("json")
local createElement = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local W = display.contentWidth
local H = display.contentHeight
local SCALE = W / 1536
local function s(v) return math.floor(v * SCALE + 0.5) end

-- Safe area
local SAFE_TOP = 0
if display.safeScreenOriginY and display.screenOriginY then
    SAFE_TOP = math.abs(display.safeScreenOriginY - display.screenOriginY)
end
if SAFE_TOP < s(40) then SAFE_TOP = s(40) end

-- ============================================================
-- Network
-- ============================================================
local HN = "https://hacker-news.firebaseio.com/v0"

local function fetchJSON(url, cb)
    network.request(url, "GET", function(e)
        if e.phase == "ended" and not e.isError then
            local ok, data = pcall(json.decode, e.response)
            if ok and data then cb(data) else cb(nil) end
        elseif e.isError then cb(nil) end
    end)
end

local function timeAgo(t)
    local d = os.time() - (t or 0)
    if d < 60 then return "just now"
    elseif d < 3600 then return math.floor(d / 60) .. "m"
    elseif d < 86400 then return math.floor(d / 3600) .. "h"
    else return math.floor(d / 86400) .. "d" end
end

local function domain(url)
    if not url then return nil end
    local d = url:match("https?://([^/]+)")
    if d then d = d:gsub("^www%.", "") end
    return d
end

local function storyTag(item)
    if not item then return nil end
    local t = item.title or ""
    if t:find("^Show HN") then return { label = "SHOW", bg = "#00C853", text = "#FFFFFF" }
    elseif t:find("^Ask HN") then return { label = "ASK", bg = "#2979FF", text = "#FFFFFF" }
    elseif t:find("^Tell HN") then return { label = "TELL", bg = "#FF6D00", text = "#FFFFFF" }
    elseif t:find("^Launch HN") then return { label = "NEW", bg = "#D500F9", text = "#FFFFFF" }
    end
    return nil
end

-- Score to heat color
local function scoreColor(score)
    if score >= 300 then return "#FF1744"  -- red hot
    elseif score >= 200 then return "#FF6D00"  -- orange
    elseif score >= 100 then return "#FF9100"  -- amber
    elseif score >= 50 then return "#FFC400"   -- yellow
    else return "#90A4AE" end  -- cool gray
end

local FEEDS = {
    { key = "top",  label = "Hot",     icon = "~" },
    { key = "best", label = "Best",    icon = "*" },
    { key = "new",  label = "New",     icon = "+" },
    { key = "ask",  label = "Ask",     icon = "?" },
    { key = "show", label = "Show",    icon = "!" },
}

local FEED_EPS = {
    top = "/topstories.json",
    best = "/beststories.json",
    new = "/newstories.json",
    ask = "/askstories.json",
    show = "/showstories.json",
}

-- ============================================================
-- Components
-- ============================================================

-- Featured hero card (first story)
local function HeroCard(props)
    local item = props.item
    if not item then return nil end
    local d = domain(item.url)
    local sc = scoreColor(item.score or 0)
    local tag = storyTag(item)

    return createElement("View", {
        style = {
            marginHorizontal = s(16), marginBottom = s(16),
            backgroundColor = "#1A1A2E", borderRadius = s(20),
            padding = s(24),
            borderWidth = 2, borderColor = sc,
        },
        onPress = props.onPress,
    },
        -- Top row: tag + score
        createElement("View", {
            style = { flexDirection = "row", alignItems = "center", marginBottom = s(16) },
        },
            tag and createElement("View", {
                style = {
                    backgroundColor = tag.bg, borderRadius = s(6),
                    paddingHorizontal = s(12), paddingVertical = s(4),
                    marginRight = s(10),
                },
            },
                createElement("Text", {
                    style = { fontSize = s(16), color = tag.text, fontWeight = "bold" },
                }, tag.label)
            ) or nil,
            createElement("View", {
                style = {
                    backgroundColor = sc, borderRadius = s(6),
                    paddingHorizontal = s(12), paddingVertical = s(4),
                },
            },
                createElement("Text", {
                    style = { fontSize = s(16), color = "#FFFFFF", fontWeight = "bold" },
                }, tostring(item.score or 0) .. " pts")
            ),
            createElement("View", { style = { flex = 1 } }),
            createElement("Text", {
                style = { fontSize = s(16), color = "#6C7A89" },
            }, "#1 TRENDING")
        ),
        -- Title
        createElement("Text", {
            style = {
                fontSize = s(36), color = "#FFFFFF",
                fontWeight = "bold", marginBottom = s(12),
            },
        }, item.title or ""),
        -- Domain
        d and createElement("Text", {
            style = { fontSize = s(20), color = sc, marginBottom = s(12) },
        }, d) or nil,
        -- Bottom meta
        createElement("View", {
            style = { flexDirection = "row", alignItems = "center" },
        },
            createElement("Text", {
                style = { fontSize = s(18), color = "#8899AA", marginRight = s(14) },
            }, item.by or ""),
            createElement("Text", {
                style = { fontSize = s(18), color = "#556677", marginRight = s(14) },
            }, timeAgo(item.time)),
            (item.descendants or 0) > 0 and createElement("Text", {
                style = { fontSize = s(18), color = "#7788FF" },
            }, tostring(item.descendants) .. " comments") or nil
        )
    )
end

-- Regular story card
local function StoryCard(props)
    local item = props.item
    local idx = props.index
    if not item then return nil end

    local d = domain(item.url)
    local tag = storyTag(item)
    local score = item.score or 0
    local sc = scoreColor(score)
    local isHot = score >= 100

    return createElement("View", {
        style = {
            marginHorizontal = s(16),
            marginBottom = s(10),
            backgroundColor = "#FFFFFF",
            borderRadius = s(14),
            borderWidth = 1,
            borderColor = isHot and sc or "#EAEAEF",
        },
        onPress = props.onPress,
    },
        createElement("View", {
            style = { flexDirection = "row", padding = s(16) },
        },
            -- Score indicator (left column)
            createElement("View", {
                style = {
                    width = s(56), alignItems = "center",
                    marginRight = s(14), paddingTop = s(2),
                },
            },
                createElement("View", {
                    style = {
                        width = s(48), height = s(48),
                        borderRadius = s(24),
                        backgroundColor = isHot and sc or "#F0F2F5",
                        justifyContent = "center", alignItems = "center",
                    },
                },
                    createElement("Text", {
                        style = {
                            fontSize = s(18),
                            color = isHot and "#FFFFFF" or "#888888",
                            fontWeight = "bold",
                        },
                    }, tostring(score))
                ),
                createElement("Text", {
                    style = { fontSize = s(14), color = "#BBBBBB", marginTop = s(4) },
                }, "#" .. tostring(idx))
            ),
            -- Content (right column)
            createElement("View", {
                style = { flex = 1 },
            },
                -- Tag + domain row
                (tag or d) and createElement("View", {
                    style = { flexDirection = "row", alignItems = "center", marginBottom = s(6) },
                },
                    tag and createElement("View", {
                        style = {
                            backgroundColor = tag.bg, borderRadius = s(4),
                            paddingHorizontal = s(8), paddingVertical = s(2),
                            marginRight = s(8),
                        },
                    },
                        createElement("Text", {
                            style = { fontSize = s(14), color = tag.text, fontWeight = "bold" },
                        }, tag.label)
                    ) or nil,
                    d and createElement("Text", {
                        style = { fontSize = s(16), color = "#AAAAAA" },
                    }, d) or nil
                ) or nil,
                -- Title
                createElement("Text", {
                    style = {
                        fontSize = s(24), color = "#222222",
                        fontWeight = "bold",
                    },
                }, item.title or ""),
                -- Meta
                createElement("View", {
                    style = { flexDirection = "row", alignItems = "center", marginTop = s(8) },
                },
                    createElement("Text", {
                        style = { fontSize = s(16), color = "#999999", marginRight = s(10) },
                    }, item.by or ""),
                    createElement("Text", {
                        style = { fontSize = s(16), color = "#CCCCCC", marginRight = s(10) },
                    }, timeAgo(item.time)),
                    (item.descendants or 0) > 0 and createElement("Text", {
                        style = { fontSize = s(16), color = "#7788FF" },
                    }, tostring(item.descendants) .. " replies") or nil
                )
            )
        )
    )
end

-- Section header
local function SectionHeader(props)
    return createElement("View", {
        style = {
            paddingHorizontal = s(20), paddingVertical = s(10),
            flexDirection = "row", alignItems = "center",
        },
    },
        createElement("View", {
            style = { width = s(4), height = s(24), backgroundColor = "#FF6600", borderRadius = s(2), marginRight = s(10) },
        }),
        createElement("Text", {
            style = { fontSize = s(20), color = "#888888", fontWeight = "bold" },
        }, props.title or "")
    )
end

-- Loading skeleton
local function Skeleton()
    local items = {}
    for i = 1, 5 do
        items[#items + 1] = createElement("View", {
            key = "sk" .. i,
            style = {
                marginHorizontal = s(16), marginBottom = s(10),
                backgroundColor = "#FFFFFF", borderRadius = s(14),
                padding = s(16), flexDirection = "row",
            },
        },
            createElement("View", { style = { width = s(48), height = s(48), borderRadius = s(24), backgroundColor = "#F0F2F5", marginRight = s(14) } }),
            createElement("View", { style = { flex = 1 } },
                createElement("View", { style = { height = s(16), width = s(100), backgroundColor = "#F0F2F5", borderRadius = s(4), marginBottom = s(8) } }),
                createElement("View", { style = { height = s(20), width = s(400), backgroundColor = "#F0F2F5", borderRadius = s(4), marginBottom = s(6) } }),
                createElement("View", { style = { height = s(20), width = s(300), backgroundColor = "#F5F6F8", borderRadius = s(4), marginBottom = s(8) } }),
                createElement("View", { style = { height = s(14), width = s(200), backgroundColor = "#F8F9FA", borderRadius = s(4) } })
            )
        )
    end
    return createElement("View", {}, unpack(items))
end

-- Bottom nav bar
local function BottomNav(props)
    local tabs = {}
    for i, f in ipairs(FEEDS) do
        local active = f.key == props.active
        tabs[#tabs + 1] = createElement("View", {
            key = "nav" .. i,
            style = {
                flex = 1, alignItems = "center",
                paddingVertical = s(8),
            },
            onPress = function() props.onSelect(f.key) end,
        },
            createElement("View", {
                style = {
                    width = s(40), height = s(40),
                    borderRadius = s(20),
                    backgroundColor = active and "#FF6600" or "#F0F2F5",
                    justifyContent = "center", alignItems = "center",
                    marginBottom = s(4),
                },
            },
                createElement("Text", {
                    style = {
                        fontSize = s(20),
                        color = active and "#FFFFFF" or "#AAAAAA",
                        fontWeight = "bold",
                    },
                }, f.icon)
            ),
            createElement("Text", {
                style = {
                    fontSize = s(16),
                    color = active and "#FF6600" or "#AAAAAA",
                    fontWeight = active and "bold" or "normal",
                },
            }, f.label)
        )
    end
    return createElement("View", {
        style = {
            position = "absolute", bottom = 0, left = 0, width = W,
            height = s(90), backgroundColor = "#FFFFFF",
            flexDirection = "row", alignItems = "center",
            borderTopWidth = 1, borderTopColor = "#EAEAEF",
            paddingBottom = s(10),
        },
    }, unpack(tabs))
end

-- Story detail page
local function DetailPage(props)
    local item = props.story
    if not item then return nil end
    local d = domain(item.url)
    local tag = storyTag(item)
    local sc = scoreColor(item.score or 0)
    local bodyText = item.text and (item.text:gsub("<[^>]+>", ""):gsub("&#x27;", "'"):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", "\"")) or nil

    local detailItems = {}
    detailItems[#detailItems + 1] = createElement("View", { key = "dtop", style = { height = s(12) } })

    -- Hero card
    detailItems[#detailItems + 1] = createElement("View", {
        key = "dhero",
        style = {
            marginHorizontal = s(16), marginBottom = s(12),
            padding = s(24), backgroundColor = "#1A1A2E",
            borderRadius = s(16),
        },
    },
        -- Tag + Score
        createElement("View", {
            style = { flexDirection = "row", alignItems = "center", marginBottom = s(14) },
        },
            tag and createElement("View", {
                style = {
                    backgroundColor = tag.bg, borderRadius = s(6),
                    paddingHorizontal = s(12), paddingVertical = s(4),
                    marginRight = s(10),
                },
            },
                createElement("Text", {
                    style = { fontSize = s(16), color = tag.text, fontWeight = "bold" },
                }, tag.label)
            ) or nil,
            createElement("View", {
                style = {
                    backgroundColor = sc, borderRadius = s(6),
                    paddingHorizontal = s(12), paddingVertical = s(4),
                },
            },
                createElement("Text", {
                    style = { fontSize = s(16), color = "#FFFFFF", fontWeight = "bold" },
                }, tostring(item.score or 0) .. " pts")
            )
        ),
        -- Title
        createElement("Text", {
            style = { fontSize = s(34), color = "#FFFFFF", fontWeight = "bold" },
        }, item.title or ""),
        -- Domain
        d and createElement("Text", {
            style = { fontSize = s(22), color = sc, marginTop = s(10) },
        }, d) or nil,
        -- Meta
        createElement("View", {
            style = { flexDirection = "row", marginTop = s(14) },
        },
            createElement("Text", { style = { fontSize = s(18), color = "#8899AA", marginRight = s(14) } },
                "by " .. (item.by or "?")),
            createElement("Text", { style = { fontSize = s(18), color = "#556677", marginRight = s(14) } },
                timeAgo(item.time)),
            createElement("Text", { style = { fontSize = s(18), color = "#7788FF" } },
                tostring(item.descendants or 0) .. " comments")
        )
    )

    -- URL
    if item.url then
        detailItems[#detailItems + 1] = createElement("View", {
            key = "durl",
            style = {
                marginHorizontal = s(16), marginBottom = s(12),
                padding = s(20), backgroundColor = "#FFFFFF",
                borderRadius = s(14), borderWidth = 1, borderColor = "#EAEAEF",
            },
        },
            createElement("Text", {
                style = { fontSize = s(16), color = "#AAAAAA", marginBottom = s(6) },
            }, "SOURCE"),
            createElement("Text", {
                style = { fontSize = s(20), color = "#2979FF" },
            }, item.url)
        )
    end

    -- Body
    if bodyText then
        detailItems[#detailItems + 1] = createElement("View", {
            key = "dbody",
            style = {
                marginHorizontal = s(16), marginBottom = s(12),
                padding = s(24), backgroundColor = "#FFFFFF",
                borderRadius = s(14), borderWidth = 1, borderColor = "#EAEAEF",
            },
        },
            createElement("Text", {
                style = { fontSize = s(22), color = "#333333" },
            }, bodyText)
        )
    end
    detailItems[#detailItems + 1] = createElement("View", { key = "dpad", style = { height = s(80) } })

    local topBarH = s(56) + SAFE_TOP

    return createElement("View", {
        style = {
            position = "absolute", top = 0, left = 0,
            width = W, height = H, backgroundColor = "#F4F5F7",
        },
    },
        -- Scroll (bottom z-layer)
        createElement("View", {
            style = { position = "absolute", top = topBarH, left = 0, width = W, height = H - topBarH },
        },
            createElement("ScrollView", {
                style = { width = W, height = H - topBarH },
            }, unpack(detailItems))
        ),
        -- Top bar (top z-layer)
        createElement("View", {
            style = {
                height = topBarH, paddingTop = SAFE_TOP,
                backgroundColor = "#1A1A2E",
                flexDirection = "row", alignItems = "center",
                paddingHorizontal = s(16),
            },
        },
            createElement("View", {
                style = {
                    paddingVertical = s(8), paddingHorizontal = s(14),
                    backgroundColor = "rgba(255,255,255,0.1)", borderRadius = s(8),
                },
                onPress = props.onBack,
            },
                createElement("Text", {
                    style = { fontSize = s(24), color = "#FF6600", fontWeight = "bold" },
                }, "< Back")
            ),
            createElement("View", { style = { flex = 1 } }),
            createElement("Text", {
                style = { fontSize = s(20), color = "#8888AA" },
            }, tostring(item.score or 0) .. " points")
        )
    )
end

-- ============================================================
-- Main App
-- ============================================================
local function NewsApp()
    local stories, setStories = useState({})
    local loading, setLoading = useState(true)
    local err, setErr = useState(nil)
    local feed, setFeed = useState("top")
    local detail, setDetail = useState(nil)
    local subtitle, setSubtitle = useState("Loading...")

    local function load(feedKey)
        setLoading(true)
        setErr(nil)
        setStories({})
        setSubtitle("Loading...")

        fetchJSON(HN .. (FEED_EPS[feedKey] or "/topstories.json"), function(ids)
            if not ids or #ids == 0 then
                setErr("Could not reach Hacker News")
                setLoading(false)
                setSubtitle("Offline")
                return
            end

            local n = math.min(25, #ids)
            local loaded, count = {}, 0

            for i = 1, n do
                fetchJSON(HN .. "/item/" .. ids[i] .. ".json", function(story)
                    if story then loaded[i] = story end
                    count = count + 1
                    setSubtitle(count .. "/" .. n)
                    if count >= n then
                        local result = {}
                        for j = 1, n do
                            if loaded[j] then result[#result + 1] = loaded[j] end
                        end
                        setStories(result)
                        setLoading(false)
                        setSubtitle(#result .. " stories")
                    end
                end)
            end
        end)
    end

    useEffect(function() load(feed) end, {})

    local function switchFeed(k)
        if k == feed then return end
        setFeed(k)
        load(k)
    end

    -- Build content
    local listItems = {}
    listItems[#listItems + 1] = createElement("View", { key = "toppad", style = { height = s(8) } })

    if err then
        listItems[#listItems + 1] = createElement("View", {
            key = "err",
            style = {
                margin = s(16), padding = s(24),
                backgroundColor = "#FFFFFF", borderRadius = s(14),
                borderWidth = 1, borderColor = "#FF4444",
                alignItems = "center",
            },
        },
            createElement("Text", {
                style = { fontSize = s(26), color = "#333333", fontWeight = "bold", marginBottom = s(8) },
            }, "Connection Issue"),
            createElement("Text", {
                style = { fontSize = s(20), color = "#888888", marginBottom = s(16) },
            }, err),
            createElement("View", {
                style = {
                    backgroundColor = "#FF6600", borderRadius = s(10),
                    paddingVertical = s(10), paddingHorizontal = s(28),
                },
                onPress = function() load(feed) end,
            },
                createElement("Text", {
                    style = { fontSize = s(20), color = "#FFFFFF", fontWeight = "bold" },
                }, "Retry")
            )
        )
    end

    if loading and #stories == 0 then
        listItems[#listItems + 1] = createElement(Skeleton, { key = "skel" })
    end

    -- Hero card for first story
    if #stories > 0 then
        listItems[#listItems + 1] = createElement(HeroCard, {
            key = "hero",
            item = stories[1],
            onPress = function() setDetail(stories[1]) end,
        })
        listItems[#listItems + 1] = createElement(SectionHeader, { key = "sh", title = "MORE STORIES" })
    end

    -- Regular cards for rest
    for i = 2, #stories do
        local s2 = stories[i]
        listItems[#listItems + 1] = createElement(StoryCard, {
            key = "s" .. (s2.id or i),
            item = s2, index = i,
            onPress = function() setDetail(s2) end,
        })
    end

    listItems[#listItems + 1] = createElement("View", { key = "pad", style = { height = s(120) } })

    -- Header height
    local headerH = SAFE_TOP + s(72)

    return createElement("View", {
        style = { flex = 1, width = W, height = H, backgroundColor = "#F4F5F7" },
    },
        -- List (bottom z-layer)
        createElement("View", {
            style = { position = "absolute", top = headerH, left = 0, width = W, height = H - headerH - s(90) },
        },
            createElement("ScrollView", {
                style = { width = W, height = H - headerH - s(90) },
            }, unpack(listItems))
        ),
        -- Header (top z-layer)
        createElement("View", {
            style = {
                height = headerH, paddingTop = SAFE_TOP,
                backgroundColor = "#1A1A2E",
                flexDirection = "row", alignItems = "center",
                paddingHorizontal = s(24),
            },
        },
            -- Logo
            createElement("View", {
                style = {
                    width = s(42), height = s(42),
                    backgroundColor = "#FF6600", borderRadius = s(10),
                    justifyContent = "center", alignItems = "center",
                    marginRight = s(12),
                },
            },
                createElement("Text", {
                    style = { fontSize = s(26), color = "#FFFFFF", fontWeight = "bold" },
                }, "Y")
            ),
            createElement("View", { style = { flex = 1 } },
                createElement("Text", {
                    style = { fontSize = s(28), color = "#FFFFFF", fontWeight = "bold" },
                }, "Tech News"),
                createElement("Text", {
                    style = { fontSize = s(16), color = "#6C7A89" },
                }, subtitle)
            ),
            -- Refresh
            createElement("View", {
                style = {
                    paddingVertical = s(8), paddingHorizontal = s(14),
                    backgroundColor = "rgba(255,255,255,0.08)", borderRadius = s(8),
                },
                onPress = function() load(feed) end,
            },
                createElement("Text", {
                    style = { fontSize = s(20), color = "#FF6600" },
                }, "Refresh")
            )
        ),
        -- Bottom nav
        createElement(BottomNav, { active = feed, onSelect = switchFeed }),
        -- Detail overlay
        detail and createElement(DetailPage, {
            story = detail,
            onBack = function() setDetail(nil) end,
        }) or nil
    )
end

return NewsApp
