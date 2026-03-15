-- examples/QuizApp.lua
-- 商业级问答做题系统 — 开始页、难度选择、计时、动画反馈、星级评分、历史记录
local React = require("react")
local createElement = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local W = display.contentWidth
local H = display.contentHeight
local SCALE = W / 1536
local function s(v) return math.floor(v * SCALE + 0.5) end

-- ============================================================
-- 题库数据
-- ============================================================

local DIFFICULTY = {
    easy = { label = "入门", color = "#4CAF50", icon = "E", time = 30 },
    medium = { label = "进阶", color = "#FF9800", icon = "M", time = 20 },
    hard = { label = "挑战", color = "#F44336", icon = "H", time = 15 },
}

local QUESTION_BANK = {
    easy = {
        { q = "HTML 是什么的缩写？", opts = { "Hyper Text Markup Language", "Home Tool Markup Language", "Hyperlinks Text Mark Language", "Hyper Tool Multi Language" }, a = 1 },
        { q = "CSS 代表什么？", opts = { "Computer Style Sheets", "Cascading Style Sheets", "Creative Style System", "Colorful Style Sheets" }, a = 2 },
        { q = "JavaScript 最初叫什么名字？", opts = { "JavaWeb", "LiveScript", "WebScript", "JScript" }, a = 2 },
        { q = "哪个标签用于 HTML 最大标题？", opts = { "<heading>", "<h6>", "<h1>", "<title>" }, a = 3 },
        { q = "React 是由哪家公司开发的？", opts = { "Google", "Apple", "Facebook/Meta", "Microsoft" }, a = 3 },
        { q = "哪个不是 JavaScript 数据类型？", opts = { "String", "Float", "Boolean", "Undefined" }, a = 2 },
        { q = "Git 的创建者是谁？", opts = { "Bill Gates", "Steve Jobs", "Linus Torvalds", "Mark Zuckerberg" }, a = 3 },
        { q = "HTTP 默认使用哪个端口？", opts = { "21", "80", "443", "8080" }, a = 2 },
        { q = "JSON 是什么的缩写？", opts = { "Java Standard Object Notation", "JavaScript Object Notation", "Java Source Open Network", "JavaScript Online Node" }, a = 2 },
        { q = "哪个 CSS 属性改变文字颜色？", opts = { "font-color", "text-color", "color", "fgcolor" }, a = 3 },
    },
    medium = {
        { q = "React 中 useEffect 的 cleanup 何时执行？", opts = { "组件挂载时", "组件卸载或依赖变化前", "每次渲染后", "仅初次渲染" }, a = 2 },
        { q = "Flexbox 中 justify-content 控制什么？", opts = { "交叉轴对齐", "主轴对齐", "换行方式", "排列方向" }, a = 2 },
        { q = "TCP 三次握手不包括哪个？", opts = { "SYN", "SYN-ACK", "ACK", "FIN" }, a = 4 },
        { q = "Big O 表示法 O(n log n) 代表什么？", opts = { "线性", "对数线性", "二次", "指数" }, a = 2 },
        { q = "哪个不是 SOLID 原则？", opts = { "单一职责", "开闭原则", "依赖注入", "持续集成" }, a = 4 },
        { q = "REST API 中 PUT 和 PATCH 的区别？", opts = { "没有区别", "PUT 全量更新，PATCH 部分更新", "PATCH 创建，PUT 更新", "PUT 只读，PATCH 可写" }, a = 2 },
        { q = "哈希表查找的平均时间复杂度？", opts = { "O(n)", "O(log n)", "O(1)", "O(n²)" }, a = 3 },
        { q = "哪种排序算法最坏情况是 O(n²)？", opts = { "归并排序", "堆排序", "快速排序", "计数排序" }, a = 3 },
        { q = "WebSocket 和 HTTP 的关系？", opts = { "完全无关", "WebSocket 基于 HTTP 升级", "HTTP 基于 WebSocket", "它们是同一协议" }, a = 2 },
        { q = "Docker 容器和虚拟机的核心区别？", opts = { "没有区别", "容器共享宿主内核", "虚拟机更轻量", "容器需要完整OS" }, a = 2 },
    },
    hard = {
        { q = "React Fiber 架构的核心目标？", opts = { "减少内存", "可中断渲染", "加快网络", "简化API" }, a = 2 },
        { q = "CAP 定理中不能同时满足的三项是？", opts = { "速度、安全、可靠", "一致、可用、分区容错", "读快、写快、强一致", "高并发、低延迟、高可用" }, a = 2 },
        { q = "Raft 共识算法中 Leader 选举的超时策略？", opts = { "固定超时", "随机超时", "递增超时", "无超时" }, a = 2 },
        { q = "JIT 编译器相比 AOT 的优势？", opts = { "启动更快", "可利用运行时信息优化", "代码更小", "无需运行时" }, a = 2 },
        { q = "Zero-Copy 技术减少了什么？", opts = { "网络延迟", "CPU在内核态和用户态间的数据复制", "磁盘读写", "内存分配" }, a = 2 },
        { q = "CRDTs 数据结构用于解决什么问题？", opts = { "排序效率", "分布式系统中的最终一致性", "内存泄漏", "死锁检测" }, a = 2 },
        { q = "Bloom Filter 的特点？", opts = { "无误判", "可能误判存在但不会误判不存在", "可能误判不存在但不会误判存在", "100%精确" }, a = 2 },
        { q = "Linux 内核调度器 CFS 使用什么数据结构？", opts = { "数组", "链表", "红黑树", "B+树" }, a = 3 },
        { q = "TLS 1.3 相比 1.2 的改进？", opts = { "支持更多加密算法", "握手减少到1-RTT", "兼容HTTP/1.0", "支持UDP" }, a = 2 },
        { q = "Rust 语言的所有权系统解决什么问题？", opts = { "性能优化", "内存安全（无GC）", "并发调度", "泛型编程" }, a = 2 },
    },
}

-- ============================================================
-- 组件
-- ============================================================

-- 星级显示
local function StarRating(props)
    local rating = props.rating or 0  -- 0-5
    local size = props.size or s(48)
    local stars = {}
    for i = 1, 5 do
        stars[#stars + 1] = createElement("Text", {
            key = "star_" .. i,
            style = {
                fontSize = size,
                color = i <= rating and "#FFD700" or "#E0E0E0",
                marginHorizontal = s(4),
            },
        }, i <= rating and "★" or "☆")
    end
    return createElement("View", {
        style = { flexDirection = "row", justifyContent = "center" },
    }, unpack(stars))
end

-- 倒计时环
local function CountdownTimer(props)
    local timeLeft = props.timeLeft
    local totalTime = props.totalTime
    local size = props.size or s(100)
    local ratio = timeLeft / totalTime
    local color = ratio > 0.5 and "#4CAF50" or (ratio > 0.25 and "#FF9800" or "#F44336")

    return createElement("View", {
        style = {
            width = size, height = size,
            borderRadius = size / 2,
            borderWidth = s(6),
            borderColor = color,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = ratio <= 0.25 and "rgba(244,67,54,0.12)" or "transparent",
        },
    },
        createElement("Text", {
            style = {
                fontSize = size * 0.4,
                fontWeight = "bold",
                color = color,
            },
        }, tostring(timeLeft))
    )
end

-- 进度条
local function ProgressBar(props)
    local progress = props.current / math.max(props.total, 1)
    local barWidth = W - s(120)
    return createElement("View", {
        style = {
            marginHorizontal = s(60),
            marginVertical = s(16),
        },
    },
        createElement("View", {
            style = {
                height = s(8),
                backgroundColor = "#E0E0E0",
                borderRadius = s(4),
            },
        },
            createElement("View", {
                style = {
                    height = s(8),
                    width = math.floor(progress * barWidth),
                    backgroundColor = "#7B1FA2",
                    borderRadius = s(4),
                },
            })
        ),
        createElement("View", {
            style = {
                flexDirection = "row",
                justifyContent = "space-between",
                marginTop = s(8),
            },
        },
            createElement("Text", {
                style = { fontSize = s(22), color = "#9E9E9E" },
            }, props.current .. " / " .. props.total),
            createElement("Text", {
                style = { fontSize = s(22), color = "#7B1FA2", fontWeight = "bold" },
            }, math.floor(progress * 100) .. "%")
        )
    )
end

-- 选项按钮
local function OptionButton(props)
    local bgColor = "#FFFFFF"
    local textColor = "#333333"
    local borderColor = "#E8E8E8"
    local letterBg = "#F5F5F5"
    local letterColor = "#666666"

    if props.state == "correct" then
        bgColor = "#E8F5E9"
        textColor = "#1B5E20"
        borderColor = "#4CAF50"
        letterBg = "#4CAF50"
        letterColor = "#FFFFFF"
    elseif props.state == "wrong" then
        bgColor = "#FFEBEE"
        textColor = "#B71C1C"
        borderColor = "#F44336"
        letterBg = "#F44336"
        letterColor = "#FFFFFF"
    elseif props.state == "dimmed" then
        bgColor = "#FAFAFA"
        textColor = "#BDBDBD"
        borderColor = "#F0F0F0"
        letterBg = "#F0F0F0"
        letterColor = "#BDBDBD"
    end

    return createElement("View", {
        style = {
            backgroundColor = bgColor,
            borderRadius = s(20),
            borderWidth = 2,
            borderColor = borderColor,
            padding = s(24),
            marginHorizontal = s(40),
            marginBottom = s(16),
            flexDirection = "row",
            alignItems = "center",
        },
        onPress = props.onPress,
    },
        createElement("View", {
            style = {
                width = s(52), height = s(52),
                borderRadius = s(26),
                backgroundColor = letterBg,
                justifyContent = "center",
                alignItems = "center",
                marginRight = s(20),
            },
        },
            createElement("Text", {
                style = { fontSize = s(26), fontWeight = "bold", color = letterColor },
            }, props.letter)
        ),
        createElement("Text", {
            style = { fontSize = s(30), color = textColor, flex = 1 },
        }, props.text),
        -- 正确/错误图标
        props.state == "correct" and createElement("Text", {
            style = { fontSize = s(36) },
        }, "✓") or nil,
        props.state == "wrong" and createElement("Text", {
            style = { fontSize = s(36) },
        }, "✗") or nil
    )
end

-- ============================================================
-- 页面：开始页
-- ============================================================

local function StartScreen(props)
    return createElement("View", {
        style = {
            flex = 1, width = W, height = H,
            backgroundColor = "#7B1FA2",
            justifyContent = "center",
            alignItems = "center",
        },
    },
        -- Logo (colored circle with Q)
        createElement("View", {
            style = {
                width = s(120), height = s(120), borderRadius = s(60),
                backgroundColor = "#E1BEE7",
                justifyContent = "center", alignItems = "center",
            },
        },
            createElement("Text", {
                style = { fontSize = s(72), fontWeight = "bold", color = "#4A148C" },
            }, "Q")
        ),
        createElement("Text", {
            style = {
                fontSize = s(64),
                fontWeight = "bold",
                color = "#FFFFFF",
                marginTop = s(24),
            },
        }, "知识问答"),
        createElement("Text", {
            style = {
                fontSize = s(30),
                color = "rgba(255,255,255,0.7)",
                marginTop = s(12),
            },
        }, "挑战你的知识边界"),

        -- 难度选择
        createElement("View", {
            style = {
                marginTop = s(80),
                width = W * 0.8,
                gap = s(20),
            },
        },
            createElement("Text", {
                style = {
                    fontSize = s(28),
                    color = "rgba(255,255,255,0.6)",
                    textAlign = "center",
                    marginBottom = s(8),
                },
            }, "选择难度"),

            -- 入门
            createElement("View", {
                style = {
                    backgroundColor = "rgba(255,255,255,0.1)",
                    borderRadius = s(20),
                    borderWidth = 2,
                    borderColor = "#4CAF50",
                    padding = s(28),
                    flexDirection = "row",
                    alignItems = "center",
                    justifyContent = "space-between",
                },
                onPress = function() props.onStart("easy") end,
            },
                createElement("View", {
                    style = { flexDirection = "row", alignItems = "center", gap = s(16) },
                },
                    createElement("View", {
                        style = { width = s(44), height = s(44), borderRadius = s(22), backgroundColor = "#4CAF50", justifyContent = "center", alignItems = "center" },
                    }, createElement("Text", { style = { fontSize = s(24), fontWeight = "bold", color = "#FFFFFF" } }, "E")),
                    createElement("View", {},
                        createElement("Text", {
                            style = { fontSize = s(34), fontWeight = "bold", color = "#FFFFFF" },
                        }, "入门模式"),
                        createElement("Text", {
                            style = { fontSize = s(24), color = "rgba(255,255,255,0.6)" },
                        }, "30秒/题 · 基础知识")
                    )
                ),
                createElement("Text", {
                    style = { fontSize = s(28), color = "#4CAF50" },
                }, "→")
            ),

            -- 进阶
            createElement("View", {
                style = {
                    backgroundColor = "rgba(255,255,255,0.1)",
                    borderRadius = s(20),
                    borderWidth = 2,
                    borderColor = "#FF9800",
                    padding = s(28),
                    flexDirection = "row",
                    alignItems = "center",
                    justifyContent = "space-between",
                },
                onPress = function() props.onStart("medium") end,
            },
                createElement("View", {
                    style = { flexDirection = "row", alignItems = "center", gap = s(16) },
                },
                    createElement("View", {
                        style = { width = s(44), height = s(44), borderRadius = s(22), backgroundColor = "#FF9800", justifyContent = "center", alignItems = "center" },
                    }, createElement("Text", { style = { fontSize = s(24), fontWeight = "bold", color = "#FFFFFF" } }, "M")),
                    createElement("View", {},
                        createElement("Text", {
                            style = { fontSize = s(34), fontWeight = "bold", color = "#FFFFFF" },
                        }, "进阶模式"),
                        createElement("Text", {
                            style = { fontSize = s(24), color = "rgba(255,255,255,0.6)" },
                        }, "20秒/题 · 深入理解")
                    )
                ),
                createElement("Text", {
                    style = { fontSize = s(28), color = "#FF9800" },
                }, "→")
            ),

            -- 挑战
            createElement("View", {
                style = {
                    backgroundColor = "rgba(255,255,255,0.1)",
                    borderRadius = s(20),
                    borderWidth = 2,
                    borderColor = "#F44336",
                    padding = s(28),
                    flexDirection = "row",
                    alignItems = "center",
                    justifyContent = "space-between",
                },
                onPress = function() props.onStart("hard") end,
            },
                createElement("View", {
                    style = { flexDirection = "row", alignItems = "center", gap = s(16) },
                },
                    createElement("View", {
                        style = { width = s(44), height = s(44), borderRadius = s(22), backgroundColor = "#F44336", justifyContent = "center", alignItems = "center" },
                    }, createElement("Text", { style = { fontSize = s(24), fontWeight = "bold", color = "#FFFFFF" } }, "H")),
                    createElement("View", {},
                        createElement("Text", {
                            style = { fontSize = s(34), fontWeight = "bold", color = "#FFFFFF" },
                        }, "挑战模式"),
                        createElement("Text", {
                            style = { fontSize = s(24), color = "rgba(255,255,255,0.6)" },
                        }, "15秒/题 · 专家难度")
                    )
                ),
                createElement("Text", {
                    style = { fontSize = s(28), color = "#F44336" },
                }, "→")
            )
        ),

        -- 历史最高分
        props.bestScore > 0 and createElement("View", {
            style = { marginTop = s(40), alignItems = "center" },
        },
            createElement("Text", {
                style = { fontSize = s(24), color = "rgba(255,255,255,0.5)" },
            }, "历史最高：" .. props.bestScore .. " / 10")
        ) or nil
    )
end

-- ============================================================
-- 页面：结果页
-- ============================================================

local function ResultScreen(props)
    local score = props.score
    local total = props.total
    local pct = math.floor(score / total * 100)
    local stars = pct >= 90 and 5 or (pct >= 70 and 4 or (pct >= 50 and 3 or (pct >= 30 and 2 or 1)))
    local diffInfo = DIFFICULTY[props.difficulty]
    local messages = {
        [5] = { text = "完美通关！", badge = "S+", badgeColor = "#FFD700", sub = "你是真正的知识达人！" },
        [4] = { text = "表现出色！", badge = "A", badgeColor = "#4CAF50", sub = "再接再厉，挑战满分！" },
        [3] = { text = "还不错！", badge = "B", badgeColor = "#2196F3", sub = "继续努力，你可以更好！" },
        [2] = { text = "加油！", badge = "C", badgeColor = "#FF9800", sub = "多复习一下，下次会更好！" },
        [1] = { text = "别灰心！", badge = "D", badgeColor = "#F44336", sub = "学习是一个过程，继续前进！" },
    }
    local msg = messages[stars]

    return createElement("View", {
        style = {
            flex = 1, width = W, height = H,
            backgroundColor = "#7B1FA2",
            justifyContent = "center",
            alignItems = "center",
        },
    },
        -- Grade badge
        createElement("View", {
            style = {
                width = s(120), height = s(120), borderRadius = s(60),
                backgroundColor = msg.badgeColor,
                justifyContent = "center", alignItems = "center",
            },
        },
            createElement("Text", {
                style = { fontSize = s(64), fontWeight = "bold", color = "#FFFFFF" },
            }, msg.badge)
        ),
        -- Title
        createElement("Text", {
            style = {
                fontSize = s(56),
                fontWeight = "bold",
                color = "#FFFFFF",
                marginTop = s(24),
            },
        }, msg.text),
        -- Subtitle
        createElement("Text", {
            style = {
                fontSize = s(28),
                color = "rgba(255,255,255,0.7)",
                marginTop = s(8),
            },
        }, msg.sub),
        -- Stars
        createElement("View", { style = { marginTop = s(32) } },
            createElement(StarRating, { rating = stars, size = s(56) })
        ),
        -- Score card
        createElement("View", {
            style = {
                marginTop = s(40),
                backgroundColor = "rgba(255,255,255,0.08)",
                borderRadius = s(24),
                padding = s(32),
                width = W * 0.7,
                alignItems = "center",
            },
        },
            createElement("Text", {
                style = { fontSize = s(80), fontWeight = "bold", color = "#FFFFFF" },
            }, score .. " / " .. total),
            createElement("View", {
                style = {
                    flexDirection = "row",
                    gap = s(24),
                    marginTop = s(16),
                },
            },
                createElement("View", {
                    style = { alignItems = "center" },
                },
                    createElement("Text", { style = { fontSize = s(36), fontWeight = "bold", color = "#FFFFFF" } }, pct .. "%"),
                    createElement("Text", { style = { fontSize = s(22), color = "rgba(255,255,255,0.6)" } }, "正确率")
                ),
                createElement("View", {
                    style = { alignItems = "center" },
                },
                    createElement("Text", { style = { fontSize = s(36), fontWeight = "bold", color = diffInfo.color } }, diffInfo.icon),
                    createElement("Text", { style = { fontSize = s(22), color = "rgba(255,255,255,0.6)" } }, diffInfo.label)
                ),
                createElement("View", {
                    style = { alignItems = "center" },
                },
                    createElement("Text", { style = { fontSize = s(36), fontWeight = "bold", color = "#FFFFFF" } }, tostring(props.timeBonus or 0)),
                    createElement("Text", { style = { fontSize = s(22), color = "rgba(255,255,255,0.6)" } }, "时间奖励")
                )
            )
        ),
        -- Buttons
        createElement("View", {
            style = {
                marginTop = s(48),
                flexDirection = "row",
                gap = s(20),
            },
        },
            createElement("View", {
                style = {
                    backgroundColor = "#FFFFFF",
                    borderRadius = s(20),
                    paddingVertical = s(20),
                    paddingHorizontal = s(48),
                },
                onPress = props.onRetry,
            },
                createElement("Text", {
                    style = { fontSize = s(32), fontWeight = "bold", color = "#7B1FA2" },
                }, "再来一次")
            ),
            createElement("View", {
                style = {
                    backgroundColor = "rgba(255,255,255,0.1)",
                    borderRadius = s(20),
                    borderWidth = 2,
                    borderColor = "rgba(255,255,255,0.4)",
                    paddingVertical = s(20),
                    paddingHorizontal = s(48),
                },
                onPress = props.onHome,
            },
                createElement("Text", {
                    style = { fontSize = s(32), color = "#FFFFFF" },
                }, "返回首页")
            )
        )
    )
end

-- ============================================================
-- 页面：答题页
-- ============================================================

local function QuizScreen(props)
    local questions = props.questions
    local difficulty = props.difficulty
    local diffInfo = DIFFICULTY[difficulty]

    local currentQ, setCurrentQ = useState(1)
    local score, setScore = useState(0)
    local timeBonus, setTimeBonus = useState(0)
    local selectedOption, setSelectedOption = useState(nil)
    local answered, setAnswered = useState(false)
    local timeLeft, setTimeLeft = useState(diffInfo.time)
    local timerRef = useRef(nil)

    local question = questions[currentQ]
    local letters = { "A", "B", "C", "D" }
    local total = #questions

    -- 倒计时
    useEffect(function()
        if answered then return end
        if timer and timer.performWithDelay then
            timerRef.current = timer.performWithDelay(1000, function()
                setTimeLeft(function(t)
                    if t <= 1 then
                        -- 时间到，自动跳过
                        setAnswered(true)
                        setSelectedOption(-1) -- 标记为超时
                        if timer and timer.performWithDelay then
                            timer.performWithDelay(1500, function()
                                if currentQ < total then
                                    setCurrentQ(function(q) return q + 1 end)
                                    setSelectedOption(nil)
                                    setAnswered(false)
                                    setTimeLeft(diffInfo.time)
                                else
                                    props.onFinish(score, timeBonus)
                                end
                            end)
                        end
                        return 0
                    end
                    return t - 1
                end)
            end, 0)
        end
        return function()
            if timerRef.current and timer and timer.cancel then
                timer.cancel(timerRef.current)
            end
        end
    end, {currentQ, answered})

    local function handleSelect(optionIndex)
        if answered then return end
        setSelectedOption(optionIndex)
        setAnswered(true)

        -- 停止计时
        if timerRef.current and timer and timer.cancel then
            timer.cancel(timerRef.current)
        end

        local isCorrect = optionIndex == question.a
        if isCorrect then
            setScore(function(s) return s + 1 end)
            -- 时间奖励：剩余时间越多分越高
            setTimeBonus(function(tb) return tb + timeLeft end)
            print("[Quiz] ✓ Correct! +" .. timeLeft .. " time bonus")
        else
            print("[Quiz] ✗ Wrong. Answer: " .. letters[question.a])
        end

        -- 自动前进
        if timer and timer.performWithDelay then
            timer.performWithDelay(isCorrect and 800 or 1500, function()
                if currentQ < total then
                    setCurrentQ(function(q) return q + 1 end)
                    setSelectedOption(nil)
                    setAnswered(false)
                    setTimeLeft(diffInfo.time)
                else
                    local finalScore = score + (isCorrect and 1 or 0)
                    local finalBonus = timeBonus + (isCorrect and timeLeft or 0)
                    props.onFinish(finalScore, finalBonus)
                end
            end)
        end
    end

    -- 构建选项列表
    local optionElements = {}
    for i, opt in ipairs(question.opts) do
        local state = nil
        if answered then
            if i == question.a then
                state = "correct"
            elseif i == selectedOption then
                state = "wrong"
            else
                state = "dimmed"
            end
        end
        optionElements[#optionElements + 1] = createElement(OptionButton, {
            key = "opt_" .. currentQ .. "_" .. i,
            letter = letters[i],
            text = opt,
            state = state,
            onPress = function() handleSelect(i) end,
        })
    end

    return createElement("View", {
        style = {
            flex = 1, width = W, height = H,
            backgroundColor = "#F8F8FC",
        },
    },
        -- 顶部栏
        createElement("View", {
            style = {
                height = s(140),
                backgroundColor = "#7B1FA2",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "flex-end",
                paddingHorizontal = s(32),
                paddingBottom = s(16),
            },
        },
            -- 退出按钮
            createElement("View", {
                style = { padding = s(8) },
                onPress = props.onQuit,
            },
                createElement("Text", {
                    style = { fontSize = s(28), color = "#FFFFFF" },
                }, "✕ 退出")
            ),
            -- 难度标签
            createElement("View", {
                style = {
                    backgroundColor = diffInfo.color,
                    borderRadius = s(12),
                    paddingHorizontal = s(16),
                    paddingVertical = s(6),
                },
            },
                createElement("Text", {
                    style = { fontSize = s(24), color = "#FFFFFF", fontWeight = "bold" },
                }, diffInfo.icon .. " " .. diffInfo.label)
            ),
            -- 得分
            createElement("Text", {
                style = { fontSize = s(28), color = "#FFFFFF", fontWeight = "bold" },
            }, "得分: " .. score)
        ),
        -- 进度条
        createElement(ProgressBar, { current = currentQ - 1 + (answered and 1 or 0), total = total }),
        -- 计时器 + 题号
        createElement("View", {
            style = {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                paddingHorizontal = s(40),
                marginBottom = s(20),
            },
        },
            createElement("Text", {
                style = { fontSize = s(28), color = "#666666" },
            }, "第 " .. currentQ .. " 题"),
            createElement(CountdownTimer, { timeLeft = timeLeft, totalTime = diffInfo.time, size = s(80) })
        ),
        -- 题目卡片
        createElement("View", {
            style = {
                marginHorizontal = s(40),
                marginBottom = s(28),
                padding = s(32),
                backgroundColor = "#FFFFFF",
                borderRadius = s(24),
                borderWidth = 1,
                borderColor = "#EEEEEE",
            },
        },
            createElement("Text", {
                style = {
                    fontSize = s(36),
                    color = "#212121",
                    fontWeight = "bold",
                    textAlign = "center",
                    lineHeight = s(52),
                },
            }, question.q)
        ),
        -- 选项
        unpack(optionElements)
    )
end

-- ============================================================
-- 主应用
-- ============================================================

local function QuizApp()
    local screen, setScreen = useState("start") -- "start" | "quiz" | "result"
    local difficulty, setDifficulty = useState("easy")
    local questions, setQuestions = useState({})
    local finalScore, setFinalScore = useState(0)
    local finalTimeBonus, setFinalTimeBonus = useState(0)
    local bestScore, setBestScore = useState(0)

    local function startQuiz(diff)
        setDifficulty(diff)
        -- 随机打乱题目
        local bank = {}
        for _, q in ipairs(QUESTION_BANK[diff]) do
            bank[#bank + 1] = q
        end
        -- Simple shuffle
        for i = #bank, 2, -1 do
            local j = math.random(i)
            bank[i], bank[j] = bank[j], bank[i]
        end
        setQuestions(bank)
        setScreen("quiz")
        print("[Quiz] Starting " .. diff .. " mode with " .. #bank .. " questions")
    end

    local function finishQuiz(score, timeBonus)
        setFinalScore(score)
        setFinalTimeBonus(timeBonus)
        if score > bestScore then
            setBestScore(score)
        end
        setScreen("result")
        print("[Quiz] Finished: " .. score .. "/" .. #questions .. " (time bonus: " .. timeBonus .. ")")
    end

    if screen == "start" then
        return createElement(StartScreen, {
            bestScore = bestScore,
            onStart = startQuiz,
        })
    elseif screen == "quiz" then
        return createElement(QuizScreen, {
            questions = questions,
            difficulty = difficulty,
            onFinish = finishQuiz,
            onQuit = function() setScreen("start") end,
        })
    elseif screen == "result" then
        return createElement(ResultScreen, {
            score = finalScore,
            total = #questions,
            difficulty = difficulty,
            timeBonus = finalTimeBonus,
            onRetry = function() startQuiz(difficulty) end,
            onHome = function() setScreen("start") end,
        })
    end
end

return QuizApp
