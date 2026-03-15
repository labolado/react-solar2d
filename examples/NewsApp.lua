-- examples/NewsApp.lua
-- 商业级新闻浏览器 — 模拟联网、大数据、下拉刷新、图文混排、分类筛选、详情页
local React = require("react")
local createElement = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef
local useCallback = React.useCallback
local useMemo = React.useMemo

local W = display.contentWidth
local H = display.contentHeight

-- ============================================================
-- 数据层：模拟 API 和大数据集
-- ============================================================

local CATEGORIES = { "全部", "推荐", "技术", "教育", "设计", "科学", "生活" }

local CATEGORY_COLORS = {
    ["推荐"] = { bg = "#FFF8E1", text = "#FF8F00", icon = "⭐" },
    ["技术"] = { bg = "#E3F2FD", text = "#1565C0", icon = "💻" },
    ["教育"] = { bg = "#E8F5E9", text = "#2E7D32", icon = "📚" },
    ["设计"] = { bg = "#FCE4EC", text = "#AD1457", icon = "🎨" },
    ["科学"] = { bg = "#EDE7F6", text = "#4527A0", icon = "🔬" },
    ["生活"] = { bg = "#FFF3E0", text = "#E65100", icon = "☕" },
}

-- 生成大量新闻数据 (模拟后端返回)
local function generateNewsDatabase()
    local titles = {
        { t = "React-Solar2D 正式发布 1.0：AI 生成 UI 的新纪元", c = "技术", featured = true },
        { t = "Solar2D 3.0 带来 Metal 渲染：性能提升 200%", c = "技术", featured = true },
        { t = "Lua 语言入选 2026 年度编程语言 Top 10", c = "技术" },
        { t = "儿童创意应用市场年增长 40%，物理引擎类最受欢迎", c = "教育", featured = true },
        { t = "Flexbox 布局完全指南：从入门到精通", c = "技术" },
        { t = "Yoga 布局引擎深度解析：跨平台 UI 的秘密", c = "技术" },
        { t = "2026 移动应用设计趋势：简洁、动效与个性化", c = "设计", featured = true },
        { t = "如何用 React Hooks 构建高性能状态管理", c = "技术" },
        { t = "STEM 教育革命：编程从娃娃抓起的全球实践", c = "教育" },
        { t = "色彩心理学在 UI 设计中的应用指南", c = "设计" },
        { t = "量子计算突破：首次实现 1000 量子比特纠缠", c = "科学", featured = true },
        { t = "极简主义设计的回归：Less is More 的现代诠释", c = "设计" },
        { t = "深度学习在自然语言处理中的最新进展", c = "科学" },
        { t = "远程工作 2.0：数字游牧的生活指南", c = "生活" },
        { t = "开源社区的力量：2026 年最具影响力的开源项目", c = "技术" },
        { t = "蒙特梭利教育法与数字化学习的融合之路", c = "教育" },
        { t = "响应式设计的未来：从屏幕到空间计算", c = "设计" },
        { t = "火星探测最新发现：地下水源确认存在", c = "科学", featured = true },
        { t = "正念冥想：科技从业者的压力管理指南", c = "生活" },
        { t = "WebAssembly 性能突破：接近原生执行速度", c = "技术" },
        { t = "AI 辅助教学：个性化学习路径的智能设计", c = "教育" },
        { t = "暗模式设计规范：不只是换个颜色那么简单", c = "设计" },
        { t = "基因编辑技术 CRISPR 3.0 获 FDA 批准", c = "科学" },
        { t = "数字排毒：如何建立健康的屏幕时间习惯", c = "生活" },
        { t = "Rust 语言在嵌入式开发中的崛起", c = "技术" },
        { t = "游戏化学习：让孩子爱上数学的 10 种方法", c = "教育" },
        { t = "动态排版：让文字成为设计的主角", c = "设计" },
        { t = "核聚变实验取得里程碑式进展", c = "科学" },
        { t = "高效能人士的 7 个数字工具推荐", c = "生活" },
        { t = "微服务架构最佳实践：从混乱到秩序", c = "技术" },
        { t = "创客教育：3D 打印在课堂中的 100 种用法", c = "教育" },
        { t = "无障碍设计不是可选项：构建包容性产品", c = "设计" },
        { t = "太空旅游商业化：2027 年首趟月球轨道之旅", c = "科学" },
        { t = "城市农场：在阳台上种菜的完整指南", c = "生活" },
        { t = "GraphQL vs REST：2026 年 API 选型指南", c = "技术" },
        { t = "双语教育的认知优势：最新神经科学研究", c = "教育" },
        { t = "3D 界面设计：超越平面的交互体验", c = "设计" },
        { t = "海洋生物多样性保护取得重大突破", c = "科学" },
        { t = "慢生活哲学：在快节奏世界中找到平衡", c = "生活" },
        { t = "Edge Computing 边缘计算改变 IoT 格局", c = "技术" },
        { t = "编程思维训练：逻辑能力培养的系统方法", c = "教育" },
        { t = "设计系统构建指南：从组件到生态", c = "设计" },
        { t = "可控核聚变离商用还有多远？", c = "科学" },
        { t = "极简数字生活：只用 5 个 App 的 30 天挑战", c = "生活" },
        { t = "容器编排最新进展：Kubernetes 2.0 前瞻", c = "技术" },
        { t = "项目制学习 PBL：芬兰教育成功的秘密", c = "教育" },
        { t = "声音设计：被忽视的用户体验维度", c = "设计" },
        { t = "暗物质研究新线索：粒子物理的重大发现", c = "科学" },
        { t = "四季养生食谱：跟着节气吃出健康", c = "生活" },
        { t = "零信任安全架构：企业防护的新范式", c = "技术" },
    }

    local summaries = {
        "这项突破性成果引发了业界广泛关注，专家认为这将深刻改变相关领域的发展方向。",
        "最新研究表明，这一技术已经具备了大规模商用的基本条件，预计将在未来两年内普及。",
        "来自全球顶尖研究机构的团队历时三年完成了这项成果，论文已发表在顶级期刊上。",
        "行业分析师指出，这一趋势将持续加速，预计到 2028 年市场规模将达到千亿级别。",
        "多位领域专家在接受采访时表示，这标志着一个新时代的开始，影响将是深远的。",
        "该项目的成功经验已被多个国家和地区借鉴，成为全球范围内的标杆案例。",
        "通过大量实验数据的支撑，研究团队证实了这一方法的有效性和可靠性。",
        "社区反响热烈，短短一周内相关讨论已超过十万条，开发者们纷纷表达了期待。",
    }

    local times = {
        "刚刚", "3 分钟前", "15 分钟前", "1 小时前", "2 小时前",
        "3 小时前", "5 小时前", "8 小时前", "12 小时前",
        "1 天前", "1 天前", "2 天前", "2 天前", "3 天前", "3 天前",
        "4 天前", "5 天前", "6 天前", "1 周前", "1 周前",
    }

    local articles = {}
    for i, item in ipairs(titles) do
        articles[#articles + 1] = {
            id = tostring(i),
            title = item.t,
            category = item.c,
            featured = item.featured or false,
            summary = summaries[(i - 1) % #summaries + 1],
            time = times[(i - 1) % #times + 1],
            readCount = math.random(100, 99999),
            commentCount = math.random(0, 999),
            liked = false,
            read = false,
            -- 模拟图片（用颜色块代替）
            imageColor = string.format("#%02X%02X%02X",
                math.random(60, 200), math.random(60, 200), math.random(60, 200)),
        }
    end
    return articles
end

-- 模拟网络请求
local function simulateFetch(callback, delay)
    if timer and timer.performWithDelay then
        timer.performWithDelay(delay or 800, function()
            callback()
        end)
    else
        callback()
    end
end

-- 格式化数字 (10000 → 1.0万)
local function formatCount(n)
    if n >= 10000 then
        return string.format("%.1f万", n / 10000)
    end
    return tostring(n)
end

-- ============================================================
-- 组件
-- ============================================================

-- 骨架屏加载占位
local function SkeletonCard(props)
    return createElement("View", {
        style = {
            marginHorizontal = 32,
            marginBottom = 20,
            padding = 28,
            backgroundColor = "#FFFFFF",
            borderRadius = 16,
        },
    },
        -- Title skeleton
        createElement("View", {
            style = {
                height = 28,
                width = W * 0.7,
                backgroundColor = "#F0F0F0",
                borderRadius = 6,
                marginBottom = 12,
            },
        }),
        -- Second line
        createElement("View", {
            style = {
                height = 28,
                width = W * 0.5,
                backgroundColor = "#F0F0F0",
                borderRadius = 6,
                marginBottom = 20,
            },
        }),
        -- Summary skeleton
        createElement("View", {
            style = {
                height = 20,
                width = W * 0.85,
                backgroundColor = "#F5F5F5",
                borderRadius = 4,
                marginBottom = 8,
            },
        }),
        createElement("View", {
            style = {
                height = 20,
                width = W * 0.6,
                backgroundColor = "#F5F5F5",
                borderRadius = 4,
            },
        })
    )
end

-- 加载中界面
local function LoadingScreen()
    local skeletons = {}
    for i = 1, 6 do
        skeletons[#skeletons + 1] = createElement(SkeletonCard, { key = "sk_" .. i })
    end
    return createElement("View", {
        style = { flex = 1, paddingTop = 20 },
    }, unpack(skeletons))
end

-- 分类标签栏
local function CategoryTabs(props)
    local tabs = {}
    for i, cat in ipairs(CATEGORIES) do
        local isActive = cat == props.active
        tabs[#tabs + 1] = createElement("View", {
            key = "cat_" .. i,
            style = {
                paddingHorizontal = 28,
                paddingVertical = 14,
                borderRadius = 24,
                backgroundColor = isActive and "#1976D2" or "transparent",
                marginRight = 8,
            },
            onPress = function()
                props.onSelect(cat)
            end,
        },
            createElement("Text", {
                style = {
                    fontSize = 28,
                    color = isActive and "#FFFFFF" or "#666666",
                    fontWeight = isActive and "bold" or "normal",
                },
            }, cat)
        )
    end

    return createElement("ScrollView", {
        style = {
            height = 64,
            width = W,
        },
        horizontal = true,
    },
        createElement("View", {
            style = {
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 24,
                height = 64,
            },
        }, unpack(tabs))
    )
end

-- 特色新闻卡片（大图）
local function FeaturedCard(props)
    local item = props.item
    local catInfo = CATEGORY_COLORS[item.category] or { bg = "#F5F5F5", text = "#666", icon = "📄" }

    return createElement("View", {
        style = {
            marginHorizontal = 32,
            marginBottom = 24,
            borderRadius = 24,
            backgroundColor = "#FFFFFF",
            overflow = "hidden",
        },
        onPress = props.onPress,
    },
        -- 大图区域（用颜色块模拟）
        createElement("View", {
            style = {
                width = W - 64,
                height = 360,
                backgroundColor = item.imageColor,
                justifyContent = "flex-end",
                padding = 24,
            },
        },
            -- 半透明遮罩
            createElement("View", {
                style = {
                    position = "absolute",
                    bottom = 0, left = 0,
                    width = W - 64, height = 180,
                    backgroundColor = "rgba(0,0,0,100)",
                },
            }),
            -- 图片上的标题
            createElement("Text", {
                style = {
                    fontSize = 38,
                    color = "#FFFFFF",
                    fontWeight = "bold",
                    zIndex = 10,
                },
            }, item.title)
        ),
        -- 底部信息
        createElement("View", {
            style = {
                padding = 24,
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
            },
        },
            createElement("View", {
                style = {
                    flexDirection = "row",
                    alignItems = "center",
                },
            },
                createElement("View", {
                    style = {
                        backgroundColor = catInfo.bg,
                        borderRadius = 8,
                        paddingHorizontal = 14,
                        paddingVertical = 4,
                        marginRight = 12,
                    },
                },
                    createElement("Text", {
                        style = { fontSize = 22, color = catInfo.text, fontWeight = "bold" },
                    }, catInfo.icon .. " " .. item.category)
                ),
                createElement("Text", {
                    style = { fontSize = 22, color = "#BDBDBD" },
                }, item.time)
            ),
            createElement("View", {
                style = { flexDirection = "row", alignItems = "center", gap = 16 },
            },
                createElement("Text", {
                    style = { fontSize = 22, color = "#BDBDBD" },
                }, "👁 " .. formatCount(item.readCount)),
                createElement("Text", {
                    style = { fontSize = 22, color = "#BDBDBD" },
                }, "💬 " .. formatCount(item.commentCount))
            )
        )
    )
end

-- 普通新闻卡片（缩略图）
local function NewsCard(props)
    local item = props.item
    local catInfo = CATEGORY_COLORS[item.category] or { bg = "#F5F5F5", text = "#666", icon = "📄" }
    local isRead = item.read

    return createElement("View", {
        style = {
            marginHorizontal = 32,
            marginBottom = 16,
            padding = 24,
            backgroundColor = "#FFFFFF",
            borderRadius = 16,
            flexDirection = "row",
        },
        onPress = props.onPress,
    },
        -- 文字区域
        createElement("View", {
            style = {
                flex = 1,
                marginRight = 16,
                justifyContent = "space-between",
            },
        },
            -- 标题
            createElement("Text", {
                style = {
                    fontSize = 32,
                    color = isRead and "#999999" or "#212121",
                    fontWeight = "bold",
                    marginBottom = 8,
                },
            }, item.title),
            -- 底部元信息
            createElement("View", {
                style = {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 12,
                },
            },
                createElement("View", {
                    style = {
                        backgroundColor = catInfo.bg,
                        borderRadius = 6,
                        paddingHorizontal = 10,
                        paddingVertical = 3,
                    },
                },
                    createElement("Text", {
                        style = { fontSize = 20, color = catInfo.text },
                    }, item.category)
                ),
                createElement("Text", {
                    style = { fontSize = 20, color = "#BDBDBD" },
                }, item.time),
                createElement("Text", {
                    style = { fontSize = 20, color = "#BDBDBD" },
                }, formatCount(item.readCount) .. " 阅读")
            )
        ),
        -- 缩略图（颜色块模拟）
        createElement("View", {
            style = {
                width = 160,
                height = 120,
                borderRadius = 12,
                backgroundColor = item.imageColor,
            },
        })
    )
end

-- 文章详情页
local function ArticleDetail(props)
    local item = props.article
    if not item then return nil end
    local catInfo = CATEGORY_COLORS[item.category] or { bg = "#F5F5F5", text = "#666", icon = "📄" }

    -- 生成模拟正文段落
    local paragraphs = {
        item.summary,
        "在当今快速发展的科技领域，这一进展无疑具有里程碑式的意义。多位行业专家在接受采访时表示，这将深刻影响未来几年的发展方向。",
        "据了解，该项目历经多年研发，投入了大量人力和资源。研究团队克服了诸多技术难题，最终取得了这一突破性成果。",
        "\"这是一个令人振奋的时刻，\" 项目负责人在发布会上表示，\"我们的目标不仅是技术创新，更是要让这项技术真正服务于社会。\"",
        "业内分析人士指出，随着这一技术的成熟和推广，相关产业链将迎来新一轮增长。预计到 2028 年，市场规模将达到数百亿元。",
        "然而，也有专家提醒，在快速发展的同时，需要关注潜在的风险和挑战。如何在创新与安全之间找到平衡，将是未来需要持续探讨的课题。",
        "无论如何，这一成果的取得标志着一个新阶段的开始。我们有理由相信，在全球研究者的共同努力下，更多令人期待的突破即将到来。",
    }

    local contentChildren = {}
    -- 返回按钮
    contentChildren[#contentChildren + 1] = createElement("View", {
        key = "back_btn",
        style = {
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 32,
            paddingVertical = 20,
        },
        onPress = props.onBack,
    },
        createElement("Text", {
            style = { fontSize = 32, color = "#1976D2" },
        }, "← 返回")
    )

    -- 大图
    contentChildren[#contentChildren + 1] = createElement("View", {
        key = "hero_img",
        style = {
            width = W,
            height = 480,
            backgroundColor = item.imageColor,
        },
    })

    -- 标题区域
    contentChildren[#contentChildren + 1] = createElement("View", {
        key = "title_area",
        style = {
            padding = 32,
            paddingBottom = 16,
        },
    },
        -- 类别 + 时间
        createElement("View", {
            style = {
                flexDirection = "row",
                alignItems = "center",
                marginBottom = 16,
                gap = 12,
            },
        },
            createElement("View", {
                style = {
                    backgroundColor = catInfo.bg,
                    borderRadius = 10,
                    paddingHorizontal = 16,
                    paddingVertical = 6,
                },
            },
                createElement("Text", {
                    style = { fontSize = 24, color = catInfo.text, fontWeight = "bold" },
                }, catInfo.icon .. " " .. item.category)
            ),
            createElement("Text", {
                style = { fontSize = 24, color = "#BDBDBD" },
            }, item.time)
        ),
        -- 标题
        createElement("Text", {
            style = {
                fontSize = 44,
                color = "#212121",
                fontWeight = "bold",
                lineHeight = 60,
            },
        }, item.title),
        -- 统计
        createElement("View", {
            style = {
                flexDirection = "row",
                marginTop = 16,
                gap = 24,
            },
        },
            createElement("Text", {
                style = { fontSize = 24, color = "#9E9E9E" },
            }, "👁 " .. formatCount(item.readCount) .. " 阅读"),
            createElement("Text", {
                style = { fontSize = 24, color = "#9E9E9E" },
            }, "💬 " .. formatCount(item.commentCount) .. " 评论")
        ),
        -- 分割线
        createElement("View", {
            style = {
                height = 1,
                backgroundColor = "#EEEEEE",
                marginTop = 24,
            },
        })
    )

    -- 正文段落
    for i, para in ipairs(paragraphs) do
        contentChildren[#contentChildren + 1] = createElement("View", {
            key = "para_" .. i,
            style = {
                paddingHorizontal = 32,
                marginBottom = 24,
            },
        },
            createElement("Text", {
                style = {
                    fontSize = 32,
                    color = "#424242",
                    lineHeight = 52,
                },
            }, "　　" .. para)
        )
    end

    -- 底部间距
    contentChildren[#contentChildren + 1] = createElement("View", {
        key = "bottom_spacer",
        style = { height = 100 },
    })

    return createElement("View", {
        style = {
            position = "absolute",
            top = 0, left = 0,
            width = W, height = H,
            backgroundColor = "#FFFFFF",
            zIndex = 50,
        },
    },
        createElement("ScrollView", {
            style = { width = W, height = H },
        }, unpack(contentChildren))
    )
end

-- 下拉刷新指示器
local function RefreshIndicator(props)
    if not props.visible then return nil end
    return createElement("View", {
        style = {
            height = 60,
            justifyContent = "center",
            alignItems = "center",
        },
    },
        createElement("Text", {
            style = { fontSize = 24, color = "#999999" },
        }, props.refreshing and "正在刷新..." or "下拉刷新")
    )
end

-- 加载更多指示器
local function LoadMoreIndicator(props)
    if not props.visible then return nil end
    return createElement("View", {
        style = {
            height = 80,
            justifyContent = "center",
            alignItems = "center",
            paddingVertical = 20,
        },
    },
        createElement("Text", {
            style = { fontSize = 24, color = "#BDBDBD" },
        }, props.loading and "加载中..." or (props.hasMore and "上拉加载更多" or "— 没有更多了 —"))
    )
end

-- 导航栏
local function NavBar(props)
    return createElement("View", {
        style = {
            height = 130,
            backgroundColor = "#1976D2",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "flex-end",
            paddingHorizontal = 32,
            paddingBottom = 16,
        },
    },
        createElement("Text", {
            style = {
                fontSize = 48,
                color = "#FFFFFF",
                fontWeight = "bold",
            },
        }, "新闻"),
        createElement("View", {
            style = { flexDirection = "row", gap = 20, alignItems = "center" },
        },
            createElement("Text", {
                style = { fontSize = 24, color = "rgba(255,255,255,180)" },
            }, tostring(props.totalCount) .. " 篇文章")
        )
    )
end

-- ============================================================
-- 主应用
-- ============================================================

local function NewsApp()
    -- 状态管理
    local allArticles, setAllArticles = useState({})
    local isLoading, setIsLoading = useState(true)
    local isRefreshing, setIsRefreshing = useState(false)
    local isLoadingMore, setIsLoadingMore = useState(false)
    local activeCategory, setActiveCategory = useState("全部")
    local displayCount, setDisplayCount = useState(10)
    local selectedArticle, setSelectedArticle = useState(nil)
    local readArticles, setReadArticles = useState({})

    -- 初始加载
    useEffect(function()
        simulateFetch(function()
            math.randomseed(os.time())
            setAllArticles(generateNewsDatabase())
            setIsLoading(false)
            print("[NewsApp] Loaded " .. 50 .. " articles")
        end, 1200)
    end, {})

    -- 下拉刷新
    local function handleRefresh()
        setIsRefreshing(true)
        print("[NewsApp] Refreshing...")
        simulateFetch(function()
            math.randomseed(os.time())
            setAllArticles(generateNewsDatabase())
            setDisplayCount(10)
            setIsRefreshing(false)
            print("[NewsApp] Refresh complete")
        end, 1000)
    end

    -- 加载更多
    local function handleLoadMore()
        if isLoadingMore then return end
        setIsLoadingMore(true)
        print("[NewsApp] Loading more...")
        simulateFetch(function()
            setDisplayCount(function(c) return c + 10 end)
            setIsLoadingMore(false)
        end, 600)
    end

    -- 过滤文章
    local filteredArticles = {}
    for _, article in ipairs(allArticles) do
        if activeCategory == "全部" or activeCategory == "推荐" and article.featured or article.category == activeCategory then
            filteredArticles[#filteredArticles + 1] = article
        end
    end

    -- 分页
    local displayArticles = {}
    local maxDisplay = math.min(displayCount, #filteredArticles)
    for i = 1, maxDisplay do
        displayArticles[i] = filteredArticles[i]
    end
    local hasMore = maxDisplay < #filteredArticles

    -- 打开文章
    local function openArticle(article)
        -- 标记已读
        article.read = true
        article.readCount = article.readCount + 1
        setSelectedArticle(article)
        print("[NewsApp] Opened: " .. article.title)
    end

    -- 加载中状态
    if isLoading then
        return createElement("View", {
            style = { flex = 1, width = W, height = H, backgroundColor = "#F5F5F5" },
        },
            createElement(NavBar, { totalCount = 0 }),
            createElement(LoadingScreen)
        )
    end

    -- 构建文章列表
    local listChildren = {}

    -- 刷新指示器
    listChildren[#listChildren + 1] = createElement(RefreshIndicator, {
        key = "refresh",
        visible = isRefreshing,
        refreshing = isRefreshing,
    })

    -- 间距
    listChildren[#listChildren + 1] = createElement("View", {
        key = "top_spacer",
        style = { height = 16 },
    })

    -- 文章卡片
    for i, article in ipairs(displayArticles) do
        if article.featured and activeCategory ~= "推荐" and i <= 3 then
            listChildren[#listChildren + 1] = createElement(FeaturedCard, {
                key = "art_" .. article.id,
                item = article,
                onPress = function() openArticle(article) end,
            })
        else
            listChildren[#listChildren + 1] = createElement(NewsCard, {
                key = "art_" .. article.id,
                item = article,
                onPress = function() openArticle(article) end,
            })
        end
    end

    -- 加载更多
    listChildren[#listChildren + 1] = createElement(LoadMoreIndicator, {
        key = "load_more",
        visible = true,
        loading = isLoadingMore,
        hasMore = hasMore,
    })

    -- 底部安全区
    listChildren[#listChildren + 1] = createElement("View", {
        key = "bottom_safe",
        style = { height = 40 },
    })

    return createElement("View", {
        style = {
            flex = 1,
            width = W, height = H,
            backgroundColor = "#F5F5F5",
        },
    },
        -- 导航栏
        createElement(NavBar, { totalCount = #filteredArticles }),
        -- 分类标签栏
        createElement("View", {
            style = {
                backgroundColor = "#FFFFFF",
                borderBottomWidth = 1,
                borderBottomColor = "#EEEEEE",
            },
        },
            createElement(CategoryTabs, {
                active = activeCategory,
                onSelect = function(cat)
                    setActiveCategory(cat)
                    setDisplayCount(10)
                    print("[NewsApp] Category: " .. cat)
                end,
            })
        ),
        -- 文章列表
        createElement("ScrollView", {
            style = {
                flex = 1,
                width = W,
                height = H - 200,
            },
            onRefresh = handleRefresh,
            refreshing = isRefreshing,
        }, unpack(listChildren)),
        -- 文章详情（覆盖层）
        selectedArticle and createElement(ArticleDetail, {
            article = selectedArticle,
            onBack = function()
                setSelectedArticle(nil)
            end,
        }) or nil
    )
end

return NewsApp
