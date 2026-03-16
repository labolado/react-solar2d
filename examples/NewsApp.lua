-- examples/NewsApp.lua
-- 中文新闻阅读器 — 网易新闻 + 百度热搜 + V2EX
local React = require("react")
local json = require("json")
local ce = React.createElement
local useState = React.useState
local useEffect = React.useEffect

local W = display.contentWidth
local H = display.contentHeight
local SC = W / 1536
local function s(v) return math.floor(v * SC + 0.5) end

local SAFE_TOP = 0
if display.safeScreenOriginY and display.screenOriginY then
    SAFE_TOP = math.abs(display.safeScreenOriginY - display.screenOriginY)
end
if SAFE_TOP < s(40) then SAFE_TOP = s(40) end

local CARD_W = W - s(40)
local TEXT_W = CARD_W - s(56)
local TEXT_W_WITHIMG = TEXT_W - s(130)
local TEXT_W_FULL = W - s(64)

-- ============================================================
-- 设计令牌
-- ============================================================
local C = {
    bg       = "#F5F5F7",
    headerBg = "#1B1B2F",
    cardBg   = "#FFFFFF",
    accent   = "#E74C3C",
    text1    = "#1A1A2E",
    text2    = "#4A4A5A",
    text3    = "#8E8E9E",
    text4    = "#C0C0CC",
    divider  = "#EFEFEF",
    blue     = "#2979FF",
}

-- ============================================================
-- 工具函数
-- ============================================================
local function utf8Sub(str, maxChars)
    if not str or str == "" then return "" end
    str = str:gsub("\n", " "):gsub("%s+", " ")
    local count, i = 0, 1
    local len = #str
    while i <= len and count < maxChars do
        local b = string.byte(str, i)
        if b < 128 then i = i + 1
        elseif b < 224 then i = i + 2
        elseif b < 240 then i = i + 3
        else i = i + 4 end
        count = count + 1
    end
    if i <= len then return string.sub(str, 1, i - 1) .. "..." end
    return str
end

local function stripHtml(str)
    if not str then return "" end
    -- Preserve paragraph structure from HTML
    str = str:gsub("</p>", "\n\n")
    str = str:gsub("<br%s*/?>", "\n")
    str = str:gsub("<p[^>]*>", "")
    -- Remove remaining tags
    str = str:gsub("<[^>]+>", "")
    -- Decode entities
    str = str:gsub("&nbsp;", " ")
    str = str:gsub("&amp;", "&")
    str = str:gsub("&lt;", "<")
    str = str:gsub("&gt;", ">")
    str = str:gsub("&quot;", '"')
    str = str:gsub("&#(%d+);", function(n) return string.char(tonumber(n)) end)
    -- Clean up whitespace while preserving newlines
    str = str:gsub("[ \t]+", " ")
    str = str:gsub("\n ", "\n")
    str = str:gsub(" \n", "\n")
    str = str:gsub("\n\n\n+", "\n\n")
    str = str:match("^%s*(.-)%s*$") or str
    return str
end

local function timeAgo(str)
    if not str or str == "" then return "" end
    -- 尝试解析 "2024-03-15 12:00:00" 格式
    local y, mo, d, h, mi = str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+)")
    if not y then return str end
    local t = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = 0 })
    local diff = os.time() - t
    if diff < 60 then return "刚刚"
    elseif diff < 3600 then return math.floor(diff / 60) .. "分钟前"
    elseif diff < 86400 then return math.floor(diff / 3600) .. "小时前"
    else return math.floor(diff / 86400) .. "天前" end
end

-- ============================================================
-- 网络
-- ============================================================
local function fetchData(url, cb)
    local params = {
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            ["Accept"] = "application/json, text/plain, */*",
            ["Accept-Language"] = "zh-CN,zh;q=0.9",
        }
    }
    network.request(url, "GET", function(e)
        if e.phase == "ended" and not e.isError then
            print("[News] " .. url:sub(1, 60) .. " status=" .. tostring(e.status))
            if e.response then
                print("[News] len=" .. #e.response .. " preview=" .. e.response:sub(1, 200))
            end
            -- 处理 JSONP 包装 (如 artiList({...}))
            local body = e.response
            local jsonStart = body:find("{")
            local jsonEnd = body:match(".*()}")
            if jsonStart and jsonEnd then
                body = body:sub(jsonStart, jsonEnd)
            end
            local ok, data = pcall(json.decode, body)
            if ok and data then cb(data) else
                print("[News] JSON decode failed")
                cb(nil)
            end
        elseif e.isError then
            print("[News] ERR: " .. tostring(e.response))
            cb(nil)
        end
    end, params)
end

-- ============================================================
-- 数据解析
-- ============================================================

-- 网易新闻
local function parse163(data, tid)
    local items = {}
    -- 尝试不同的响应结构
    local articles = data[tid] or data
    if type(articles) ~= "table" then
        -- 遍历所有 key 找到数组
        for k, v in pairs(data) do
            if type(v) == "table" and #v > 0 then
                articles = v
                break
            end
        end
    end
    if type(articles) ~= "table" then return items end
    for i, a in ipairs(articles) do
        if type(a) == "table" and a.title and a.title ~= "" then
            items[#items + 1] = {
                id      = a.docid or tostring(i),
                title   = a.title,
                desc    = a.digest or "",
                img     = a.imgsrc or "",
                source  = a.source or "网易",
                time    = a.ptime or "",
                comments = tonumber(a.commentCount or 0) or 0,
                url     = a.url or "",
            }
        end
    end
    return items
end

-- 百度热搜
local function parseBaidu(data)
    local items = {}
    local function scan(arr)
        if type(arr) ~= "table" then return end
        for _, it in ipairs(arr) do
            if it.word or it.query then
                items[#items + 1] = {
                    id     = tostring(it.index or #items + 1),
                    title  = it.query or it.word or "",
                    desc   = it.desc or "",
                    img    = it.img or "",
                    score  = tonumber(it.hotScore or 0) or 0,
                    url    = it.rawUrl or it.url or "",
                    source = "百度热搜",
                    tag    = it.labelTagName or it.tag or "",
                }
            elseif it.content and type(it.content) == "table" then
                scan(it.content)
            end
        end
    end
    if data and data.data and data.data.cards then
        for _, card in ipairs(data.data.cards) do
            if card.content then scan(card.content) end
        end
    end
    return items
end

-- V2EX
local function parseV2EX(data)
    local items = {}
    if type(data) ~= "table" then return items end
    for i, t in ipairs(data) do
        items[#items + 1] = {
            id      = tostring(t.id or i),
            title   = t.title or "",
            desc    = stripHtml(t.content or ""),
            img     = t.member and t.member.avatar_large or "",
            score   = t.replies or 0,
            url     = t.url or "",
            source  = (t.node and t.node.title) or "V2EX",
            author  = t.member and t.member.username or "",
        }
    end
    return items
end

-- ============================================================
-- 分类
-- ============================================================
local FEEDS = {
    { key = "top",    label = "推荐", api = "163", tid = "BBM54PGAwangning" },
    { key = "tech",   label = "科技", api = "163", tid = "BA8D4A3Rwangning" },
    { key = "hot",    label = "热搜", api = "baidu", tab = "realtime" },
    { key = "v2ex",   label = "论坛", api = "v2ex" },
}

-- ============================================================
-- UI 组件
-- ============================================================

-- 头部
local function Header(props)
    local barH = SAFE_TOP + s(56)
    return ce("View", {
        style = {
            width = W, height = barH, paddingTop = SAFE_TOP,
            backgroundColor = C.headerBg,
            flexDirection = "row", alignItems = "center", paddingHorizontal = s(28),
        },
    },
        ce("View", {
            style = {
                width = s(40), height = s(40), borderRadius = s(10),
                backgroundColor = C.accent, justifyContent = "center", alignItems = "center",
                marginRight = s(12),
            },
        },
            ce("Text", { style = { fontSize = s(22), color = "#FFFFFF", fontWeight = "bold" } }, "N")
        ),
        ce("View", { style = { flex = 1 } },
            ce("Text", { style = { fontSize = s(28), color = "#FFFFFF", fontWeight = "bold" } }, "热点资讯"),
            ce("Text", { style = { fontSize = s(14), color = "#6B7280" } }, props.status or "")
        ),
        ce("View", {
            style = {
                width = s(80), height = s(40), borderRadius = s(10),
                backgroundColor = "rgba(231,76,60,0.15)",
                justifyContent = "center", alignItems = "center",
            },
            onPress = props.onRefresh,
        },
            ce("Text", { style = { fontSize = s(18), color = C.accent, fontWeight = "bold" } }, "刷新")
        )
    )
end

-- 分类标签
local function CategoryTabs(props)
    local tabs = {}
    for i, f in ipairs(FEEDS) do
        local active = f.key == props.active
        tabs[#tabs + 1] = ce("View", {
            key = "t" .. i,
            style = {
                width = s(76), height = s(36), borderRadius = s(18),
                marginRight = s(8),
                backgroundColor = active and C.accent or "rgba(255,255,255,0.06)",
                justifyContent = "center", alignItems = "center",
            },
            onPress = function() props.onSelect(f.key) end,
        },
            ce("Text", {
                style = {
                    fontSize = s(20), color = active and "#FFFFFF" or "#8B8BA0",
                    fontWeight = active and "bold" or "normal",
                },
            }, f.label)
        )
    end
    return ce("View", {
        style = {
            width = W, height = s(50), backgroundColor = C.headerBg,
            paddingHorizontal = s(28), paddingBottom = s(14), flexDirection = "row", alignItems = "center",
        },
    }, unpack(tabs))
end

-- 图文新闻卡片
local function NewsCard(props)
    local item = props.item
    local rank = props.rank
    local isHero = props.isHero
    if not item then return nil end

    local hasImg = item.img and #item.img > 10
    local hasDesc = item.desc and #item.desc > 0

    if isHero then
        -- 头条大卡片
        return ce("View", {
            style = {
                width = CARD_W, height = hasImg and s(320) or s(200),
                marginLeft = s(20), marginTop = s(14),
                backgroundColor = C.headerBg, borderRadius = s(18),
                paddingHorizontal = s(24), paddingVertical = s(20),
            },
            onPress = props.onPress,
        },
            -- 顶部来源
            ce("View", { style = { flexDirection = "row", alignItems = "center", marginBottom = s(10) } },
                ce("View", {
                    style = {
                        width = s(56), height = s(26), borderRadius = s(6),
                        backgroundColor = C.accent, justifyContent = "center", alignItems = "center",
                        marginRight = s(10),
                    },
                },
                    ce("Text", { style = { fontSize = s(13), color = "#FFFFFF", fontWeight = "bold" } }, "头条")
                ),
                ce("Text", { style = { fontSize = s(15), color = "#6B7280" } }, item.source or "")
            ),
            -- 标题+图片
            ce("View", { style = { flexDirection = "row", flex = 1 } },
                ce("View", { style = { flex = 1 } },
                    ce("Text", {
                        style = { fontSize = s(36), color = "#FFFFFF", fontWeight = "bold", width = hasImg and TEXT_W_WITHIMG or TEXT_W },
                    }, item.title),
                    hasDesc and ce("Text", {
                        style = { fontSize = s(19), color = "#9CA3AF", marginTop = s(8), width = hasImg and TEXT_W_WITHIMG or TEXT_W },
                    }, utf8Sub(item.desc, 60)) or nil
                ),
                hasImg and ce("Image", {
                    source = { uri = item.img },
                    style = { width = s(120), height = s(90), borderRadius = s(12), marginLeft = s(12) },
                }) or nil
            ),
            -- 底部信息
            ce("View", { style = { flexDirection = "row", alignItems = "center", marginTop = s(8) } },
                item.time and #(item.time or "") > 0 and ce("Text", {
                    style = { fontSize = s(14), color = "#6B7280", marginRight = s(12) },
                }, (timeAgo(item.time))) or nil,
                item.comments and item.comments > 0 and ce("Text", {
                    style = { fontSize = s(14), color = C.blue },
                }, tostring(item.comments) .. " 评论") or nil
            )
        )
    else
        -- 普通卡片
        local tw = hasImg and TEXT_W_WITHIMG or TEXT_W
        return ce("View", {
            style = {
                width = CARD_W, height = hasDesc and s(145) or s(110),
                marginLeft = s(20), marginTop = s(8),
                backgroundColor = C.cardBg, borderRadius = s(14),
                paddingHorizontal = s(20), paddingVertical = s(16),
                borderWidth = 1, borderColor = "#F0F0F5",
            },
            onPress = props.onPress,
        },
            ce("View", { style = { flexDirection = "row" } },
                -- 排名
                rank and ce("View", {
                    style = {
                        width = s(30), height = s(30), borderRadius = s(8),
                        backgroundColor = rank <= 3 and C.accent or (rank <= 6 and "#FF6B35" or "#ECECF0"),
                        justifyContent = "center", alignItems = "center",
                        marginRight = s(12), marginTop = s(2),
                    },
                },
                    ce("Text", {
                        style = { fontSize = s(15), fontWeight = "bold", color = rank <= 6 and "#FFFFFF" or C.text3 },
                    }, tostring(rank))
                ) or nil,
                -- 文字
                ce("View", { style = { flex = 1 } },
                    ce("Text", {
                        style = { fontSize = s(28), color = C.text1, fontWeight = "bold", width = tw - (rank and s(42) or 0) },
                    }, item.title),
                    hasDesc and ce("Text", {
                        style = { fontSize = s(20), color = C.text3, marginTop = s(6), width = tw - (rank and s(42) or 0) },
                    }, utf8Sub(item.desc, 50)) or nil,
                    -- meta
                    ce("View", { style = { flexDirection = "row", alignItems = "center", marginTop = s(4) } },
                        item.source and #item.source > 0 and ce("Text", {
                            style = { fontSize = s(13), color = C.text4, marginRight = s(8) },
                        }, item.source) or nil,
                        item.time and #(item.time or "") > 0 and ce("Text", {
                            style = { fontSize = s(13), color = C.text4, marginRight = s(8) },
                        }, (timeAgo(item.time))) or nil,
                        item.tag and item.tag ~= "" and ce("View", {
                            style = {
                                backgroundColor = "rgba(231,76,60,0.1)", borderRadius = s(4),
                                paddingHorizontal = s(6), paddingVertical = s(2),
                            },
                        },
                            ce("Text", { style = { fontSize = s(12), color = C.accent } }, item.tag)
                        ) or nil,
                        item.comments and item.comments > 0 and ce("Text", {
                            style = { fontSize = s(13), color = C.blue },
                        }, tostring(item.comments) .. "评论") or nil
                    )
                ),
                -- 缩略图
                hasImg and ce("Image", {
                    source = { uri = item.img },
                    style = { width = s(100), height = s(72), borderRadius = s(10), marginLeft = s(10) },
                }) or nil
            )
        )
    end
end

-- 详情页
-- 获取网易文章详情正文
local function fetchArticleBody(docid, cb)
    if not docid or docid == "" then cb(nil); return end
    local url = "https://c.m.163.com/nc/article/" .. docid .. "/full.html"
    fetchData(url, function(data)
        if not data then cb(nil); return end
        -- 尝试从 data[docid] 或 data 中提取 body
        local article = data[docid] or data
        if type(article) ~= "table" then
            -- 遍历找到第一个 table
            for _, v in pairs(data) do
                if type(v) == "table" and v.body then
                    article = v; break
                end
            end
        end
        if type(article) == "table" and article.body then
            local body = stripHtml(article.body)
            cb(body)
        else
            cb(nil)
        end
    end)
end

local function DetailView(props)
    local item = props.story
    if not item then return nil end
    local barH = s(56) + SAFE_TOP
    local bodyPad = s(36)
    local bodyW = W - bodyPad * 2

    -- 异步加载正文
    local bodyText, setBodyText = useState(nil)
    local bodyLoading, setBodyLoading = useState(false)

    useEffect(function()
        if item.id and item.id ~= "" and (not item.desc or #item.desc < 100) then
            setBodyLoading(true)
            fetchArticleBody(item.id, function(body)
                if body and #body > 0 then
                    setBodyText(body)
                end
                setBodyLoading(false)
            end)
        end
    end, {})

    local displayBody = bodyText or item.desc or ""

    local parts = {}

    -- 标题区（深色背景，大标题）
    parts[#parts + 1] = ce("View", {
        key = "dt",
        style = {
            width = W, backgroundColor = C.headerBg,
            paddingHorizontal = bodyPad, paddingTop = s(28), paddingBottom = s(32),
        },
    },
        -- 来源 + 时间
        ce("View", { style = { flexDirection = "row", alignItems = "center", marginBottom = s(16) } },
            ce("View", {
                style = {
                    backgroundColor = "rgba(231,76,60,0.2)", borderRadius = s(6),
                    paddingHorizontal = s(10), paddingVertical = s(4), marginRight = s(12),
                },
            },
                ce("Text", { style = { fontSize = s(18), color = C.accent, fontWeight = "bold" } }, item.source or "未知来源")
            ),
            item.time and #(item.time or "") > 0 and ce("Text", {
                style = { fontSize = s(18), color = "#6B7280" },
            }, (timeAgo(item.time))) or nil
        ),
        -- 标题
        ce("Text", {
            style = { fontSize = s(48), color = "#FFFFFF", fontWeight = "bold", width = bodyW },
        }, item.title)
    )

    -- 图片
    if item.img and #item.img > 10 then
        parts[#parts + 1] = ce("View", {
            key = "di",
            style = {
                width = W, paddingHorizontal = bodyPad, paddingTop = s(24), paddingBottom = s(16),
                backgroundColor = C.cardBg,
            },
        },
            ce("Image", {
                source = { uri = item.img },
                style = { width = bodyW, height = s(320), borderRadius = s(16) },
            })
        )
    end

    -- 正文内容
    if #displayBody > 0 then
        -- 分段渲染：按 \n\n 拆成段落，每段独立 Text 以获得段间距
        local paragraphs = {}
        for para in (displayBody .. "\n\n"):gmatch("(.-)%s*\n\n") do
            local trimmed = para:match("^%s*(.-)%s*$")
            if trimmed and #trimmed > 0 then
                paragraphs[#paragraphs + 1] = trimmed
            end
        end
        if #paragraphs == 0 then
            paragraphs[1] = displayBody
        end

        local bodyChildren = {}
        for i, para in ipairs(paragraphs) do
            bodyChildren[#bodyChildren + 1] = ce("Text", {
                key = "p" .. i,
                style = {
                    fontSize = s(36),
                    color = C.text1,
                    width = bodyW,
                    marginBottom = s(28),
                },
            }, para)
        end

        parts[#parts + 1] = ce("View", {
            key = "db",
            style = {
                width = W, paddingHorizontal = bodyPad, paddingTop = s(28), paddingBottom = s(12),
                backgroundColor = C.cardBg,
            },
        }, unpack(bodyChildren))
    elseif bodyLoading then
        parts[#parts + 1] = ce("View", {
            key = "dbl",
            style = {
                width = W, paddingHorizontal = bodyPad, paddingVertical = s(40),
                backgroundColor = C.cardBg, alignItems = "center",
            },
        },
            ce("Text", { style = { fontSize = s(22), color = C.text4 } }, "正文加载中...")
        )
    end

    -- 评论数
    if item.comments and item.comments > 0 then
        parts[#parts + 1] = ce("View", {
            key = "dc",
            style = {
                width = W, paddingHorizontal = bodyPad, paddingVertical = s(20),
                backgroundColor = C.cardBg, borderTopWidth = 1, borderTopColor = C.divider,
            },
        },
            ce("Text", { style = { fontSize = s(22), color = C.blue, fontWeight = "bold" } },
                tostring(item.comments) .. " 条评论")
        )
    end

    -- 原文链接
    if item.url and #item.url > 0 then
        parts[#parts + 1] = ce("View", {
            key = "dl",
            style = {
                width = W, paddingHorizontal = bodyPad, paddingVertical = s(20),
                backgroundColor = C.cardBg, borderTopWidth = 1, borderTopColor = C.divider,
            },
        },
            ce("Text", { style = { fontSize = s(17), color = C.text4, marginBottom = s(8) } }, "原文链接"),
            ce("Text", { style = { fontSize = s(19), color = C.blue, width = bodyW } },
                utf8Sub(item.url, 80))
        )
    end

    parts[#parts + 1] = ce("View", { key = "dp", style = { height = s(140) } })

    return ce("View", {
        style = {
            position = "absolute", top = 0, left = 0,
            width = W, height = H, backgroundColor = C.bg,
        },
    },
        -- 内容区域（ScrollView）
        ce("View", {
            style = { position = "absolute", top = barH, left = 0, width = W, height = H - barH },
        },
            ce("ScrollView", { style = { width = W, height = H - barH } }, unpack(parts))
        ),
        -- 顶栏返回按钮（整个区域可点击）
        ce("View", {
            style = {
                width = W, height = barH, paddingTop = SAFE_TOP,
                backgroundColor = C.headerBg,
                flexDirection = "row", alignItems = "center", paddingHorizontal = s(28),
            },
            onPress = function()
                print("[News] BACK pressed!")
                if props.onBack then props.onBack() end
            end,
        },
            ce("Text", {
                style = { fontSize = s(28), color = C.accent, fontWeight = "bold" },
            }, "< 返回"),
            ce("View", { style = { flex = 1 } }),
            ce("Text", {
                style = { fontSize = s(20), color = "#6B7280" },
            }, item.source or "")
        )
    )
end

-- 加载骨架
local function LoadingView()
    local bars = {}
    for i = 1, 5 do
        bars[#bars + 1] = ce("View", {
            key = "sk" .. i,
            style = {
                width = CARD_W, height = s(80),
                marginLeft = s(20), marginTop = s(8),
                backgroundColor = C.cardBg, borderRadius = s(14), padding = s(20),
            },
        },
            ce("View", { style = { height = s(18), width = CARD_W * (0.8 - i * 0.06), backgroundColor = "#F0F2F5", borderRadius = s(6), marginBottom = s(8) } }),
            ce("View", { style = { height = s(12), width = CARD_W * 0.4, backgroundColor = "#F5F6F8", borderRadius = s(6) } })
        )
    end
    return ce("View", {}, unpack(bars))
end

-- 错误
local function ErrorView(props)
    return ce("View", {
        style = {
            width = CARD_W, height = s(200),
            marginLeft = s(20), marginTop = s(40),
            backgroundColor = C.cardBg, borderRadius = s(20),
            padding = s(36), alignItems = "center", justifyContent = "center",
        },
    },
        ce("Text", { style = { fontSize = s(24), color = C.text1, fontWeight = "bold", marginBottom = s(8) } }, "加载失败"),
        ce("Text", { style = { fontSize = s(17), color = C.text3, marginBottom = s(20) } }, props.message or "网络连接异常"),
        ce("View", {
            style = {
                width = s(100), height = s(42),
                backgroundColor = C.accent, borderRadius = s(12),
                justifyContent = "center", alignItems = "center",
            },
            onPress = props.onRetry,
        },
            ce("Text", { style = { fontSize = s(18), color = "#FFFFFF", fontWeight = "bold" } }, "重试")
        )
    )
end

-- ============================================================
-- 主应用
-- ============================================================
local function NewsApp()
    local stories, setStories = useState({})
    local loading, setLoading = useState(true)
    local err, setErr = useState(nil)
    local feed, setFeed = useState("top")
    local detail, setDetail = useState(nil)
    local status, setStatus = useState("加载中...")

    local function load(feedKey)
        setLoading(true)
        setErr(nil)
        setStories({})
        setStatus("加载中...")

        local cfg = nil
        for _, f in ipairs(FEEDS) do
            if f.key == feedKey then cfg = f; break end
        end
        if not cfg then return end

        local function onFail(msg)
            setErr(msg or "加载失败")
            setLoading(false)
            setStatus("离线")
        end

        if cfg.api == "163" then
            local url = "https://3g.163.com/touch/reconstruct/article/list/" .. cfg.tid .. "/0-20.html"
            fetchData(url, function(data)
                if not data then onFail("网易新闻连接失败"); return end
                local result = parse163(data, cfg.tid)
                if #result == 0 then
                    print("[News] 163 returned 0 items, trying V2EX")
                    fetchData("https://www.v2ex.com/api/topics/hot.json", function(d)
                        if not d then onFail("网络连接失败"); return end
                        local r = parseV2EX(d)
                        setStories(r)
                        setLoading(false)
                        setStatus(#r .. " 条 (V2EX)")
                    end)
                    return
                end
                setStories(result)
                setLoading(false)
                setStatus(#result .. " 条新闻")
            end)

        elseif cfg.api == "baidu" then
            local url = "https://top.baidu.com/api/board?platform=wise&tab=" .. cfg.tab
            fetchData(url, function(data)
                if not data then onFail("百度热搜连接失败"); return end
                local result = parseBaidu(data)
                if #result == 0 then onFail("无法解析热搜数据"); return end
                setStories(result)
                setLoading(false)
                setStatus(#result .. " 条热搜")
            end)

        elseif cfg.api == "v2ex" then
            fetchData("https://www.v2ex.com/api/topics/hot.json", function(d)
                if not d then onFail("V2EX 连接失败"); return end
                local r = parseV2EX(d)
                setStories(r)
                setLoading(false)
                setStatus(#r .. " 条话题")
            end)
        end
    end

    useEffect(function() load(feed) end, {})

    local function switchFeed(k)
        if k == feed then return end
        setFeed(k)
        load(k)
    end

    -- 构建列表
    local list = {}

    if loading and #stories == 0 then
        list[#list + 1] = ce(LoadingView, { key = "ld" })
    end

    if err then
        list[#list + 1] = ce(ErrorView, {
            key = "er", message = err,
            onRetry = function() load(feed) end,
        })
    end

    -- 头条
    if #stories >= 1 then
        list[#list + 1] = ce(NewsCard, {
            key = "hero", item = stories[1], isHero = true,
            onPress = function() setDetail(stories[1]) end,
        })
    end

    -- 其余
    for i = 2, #stories do
        list[#list + 1] = ce(NewsCard, {
            key = "s" .. i, item = stories[i], rank = i,
            onPress = function() setDetail(stories[i]) end,
        })
    end

    list[#list + 1] = ce("View", { key = "pad", style = { height = s(100) } })

    local headerH = SAFE_TOP + s(56) + s(50)

    return ce("View", {
        style = { width = W, height = H, backgroundColor = C.bg },
    },
        ce("View", {
            style = { position = "absolute", top = headerH, left = 0, width = W, height = H - headerH },
        },
            ce("ScrollView", { style = { width = W, height = H - headerH } }, unpack(list))
        ),
        ce(Header, { status = status, onRefresh = function() load(feed) end }),
        ce(CategoryTabs, { active = feed, onSelect = switchFeed }),
        detail and ce(DetailView, { story = detail, onBack = function() setDetail(nil) end }) or nil
    )
end

return NewsApp
