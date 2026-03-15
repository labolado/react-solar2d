-- examples/QuizApp.lua
-- 问答做题系统 Demo — useState + Modal + TouchableOpacity + progress
local React = require("react")
local createElement = React.createElement
local useState = React.useState

local W = display.contentWidth
local H = display.contentHeight

-- Quiz questions
local QUESTIONS = {
    {
        question = "React 的核心思想是什么？",
        options = { "命令式编程", "声明式 UI", "面向对象", "函数式编程" },
        answer = 2,
    },
    {
        question = "Solar2D 使用什么编程语言？",
        options = { "JavaScript", "Python", "Lua", "C++" },
        answer = 3,
    },
    {
        question = "Flexbox 默认的主轴方向是？",
        options = { "row", "column", "row-reverse", "column-reverse" },
        answer = 2,
    },
    {
        question = "useState Hook 返回什么？",
        options = { "一个值", "一个函数", "值和设置函数", "一个对象" },
        answer = 3,
    },
    {
        question = "Yoga 布局引擎由哪家公司开发？",
        options = { "Google", "Apple", "Facebook/Meta", "Microsoft" },
        answer = 3,
    },
}

-- Progress bar
local function ProgressBar(props)
    local progress = props.current / props.total
    return createElement("View", {
        style = {
            height = 12,
            backgroundColor = "#E0E0E0",
            borderRadius = 6,
            marginHorizontal = 60,
            marginVertical = 20,
        },
    },
        createElement("View", {
            style = {
                height = 12,
                width = math.floor(progress * (W - 120)),
                backgroundColor = "#4CAF50",
                borderRadius = 6,
            },
        })
    )
end

-- Option button
local function OptionButton(props)
    local bgColor = "#FFFFFF"
    local textColor = "#333333"
    local borderColor = "#E0E0E0"

    if props.state == "correct" then
        bgColor = "#E8F5E9"
        textColor = "#2E7D32"
        borderColor = "#4CAF50"
    elseif props.state == "wrong" then
        bgColor = "#FFEBEE"
        textColor = "#C62828"
        borderColor = "#F44336"
    elseif props.state == "selected" then
        bgColor = "#E3F2FD"
        textColor = "#1565C0"
        borderColor = "#2196F3"
    end

    return createElement("View", {
        style = {
            backgroundColor = bgColor,
            borderRadius = 16,
            borderWidth = 3,
            borderColor = borderColor,
            padding = 28,
            marginHorizontal = 60,
            marginBottom = 20,
        },
        onPress = props.onPress,
    },
        createElement("View", {
            style = {
                flexDirection = "row",
                alignItems = "center",
            },
        },
            -- Option letter
            createElement("View", {
                style = {
                    width = 56, height = 56,
                    borderRadius = 28,
                    backgroundColor = borderColor,
                    justifyContent = "center",
                    alignItems = "center",
                    marginRight = 20,
                },
            },
                createElement("Text", {
                    style = {
                        fontSize = 28,
                        color = "#FFFFFF",
                        fontWeight = "bold",
                    },
                }, props.letter)
            ),
            -- Option text
            createElement("Text", {
                style = {
                    fontSize = 32,
                    color = textColor,
                    flex = 1,
                },
            }, props.text)
        )
    )
end

-- Result modal
local function ResultModal(props)
    if not props.visible then return nil end

    local score = props.score
    local total = props.total
    local pct = math.floor(score / total * 100)
    local emoji = pct >= 80 and "🎉" or (pct >= 60 and "👍" or "💪")
    local message = pct >= 80 and "太棒了！" or (pct >= 60 and "不错！" or "继续加油！")

    return createElement("View", {
        style = {
            position = "absolute",
            top = 0, left = 0,
            width = W, height = H,
            backgroundColor = "rgba(0,0,0,128)",
            justifyContent = "center",
            alignItems = "center",
            zIndex = 100,
        },
    },
        createElement("View", {
            style = {
                width = W * 0.75,
                backgroundColor = "#FFFFFF",
                borderRadius = 32,
                padding = 60,
                alignItems = "center",
            },
        },
            createElement("Text", {
                style = { fontSize = 96 },
            }, emoji),
            createElement("Text", {
                style = {
                    fontSize = 48,
                    fontWeight = "bold",
                    color = "#333333",
                    marginTop = 24,
                },
            }, message),
            createElement("Text", {
                style = {
                    fontSize = 72,
                    fontWeight = "bold",
                    color = "#2196F3",
                    marginTop = 20,
                },
            }, score .. " / " .. total),
            createElement("Text", {
                style = {
                    fontSize = 32,
                    color = "#9E9E9E",
                    marginTop = 12,
                },
            }, "正确率 " .. pct .. "%"),
            -- Retry button
            createElement("View", {
                style = {
                    marginTop = 40,
                    backgroundColor = "#4CAF50",
                    borderRadius = 20,
                    paddingVertical = 20,
                    paddingHorizontal = 60,
                },
                onPress = props.onRetry,
            },
                createElement("Text", {
                    style = {
                        fontSize = 36,
                        color = "#FFFFFF",
                        fontWeight = "bold",
                    },
                }, "再来一次")
            )
        )
    )
end

-- Main QuizApp
local function QuizApp()
    local currentQ, setCurrentQ = useState(1)
    local score, setScore = useState(0)
    local selectedOption, setSelectedOption = useState(nil)
    local answered, setAnswered = useState(false)
    local showResult, setShowResult = useState(false)

    local question = QUESTIONS[currentQ]
    local letters = { "A", "B", "C", "D" }

    local function handleSelect(optionIndex)
        if answered then return end
        setSelectedOption(optionIndex)
        setAnswered(true)

        if optionIndex == question.answer then
            setScore(function(s) return s + 1 end)
            print("[Quiz] Correct!")
        else
            print("[Quiz] Wrong! Answer was: " .. letters[question.answer])
        end

        -- Auto advance after delay (via timer in Solar2D)
        if timer and timer.performWithDelay then
            timer.performWithDelay(1200, function()
                if currentQ < #QUESTIONS then
                    setCurrentQ(function(q) return q + 1 end)
                    setSelectedOption(nil)
                    setAnswered(false)
                else
                    setShowResult(true)
                end
            end)
        end
    end

    local function handleRetry()
        setCurrentQ(1)
        setScore(0)
        setSelectedOption(nil)
        setAnswered(false)
        setShowResult(false)
    end

    return createElement("View", {
        style = {
            flex = 1,
            backgroundColor = "#F5F5F5",
            width = W, height = H,
        },
    },
        -- Header
        createElement("View", {
            style = {
                height = 140,
                backgroundColor = "#7B1FA2",
                justifyContent = "center",
                alignItems = "center",
                paddingTop = 30,
            },
        },
            createElement("Text", {
                style = {
                    fontSize = 48,
                    color = "#FFFFFF",
                    fontWeight = "bold",
                },
            }, "📝 知识问答")
        ),
        -- Progress
        createElement(ProgressBar, {
            current = answered and currentQ or (currentQ - 1),
            total = #QUESTIONS,
        }),
        -- Question counter
        createElement("Text", {
            style = {
                fontSize = 28,
                color = "#9E9E9E",
                textAlign = "center",
                marginBottom = 16,
            },
        }, "第 " .. currentQ .. " / " .. #QUESTIONS .. " 题"),
        -- Question text
        createElement("View", {
            style = {
                marginHorizontal = 60,
                marginBottom = 32,
                padding = 32,
                backgroundColor = "#FFFFFF",
                borderRadius = 20,
            },
        },
            createElement("Text", {
                style = {
                    fontSize = 38,
                    color = "#212121",
                    fontWeight = "bold",
                    textAlign = "center",
                },
            }, question.question)
        ),
        -- Options
        unpack((function()
            local opts = {}
            for i, opt in ipairs(question.options) do
                local state = nil
                if answered then
                    if i == question.answer then
                        state = "correct"
                    elseif i == selectedOption then
                        state = "wrong"
                    end
                elseif i == selectedOption then
                    state = "selected"
                end
                opts[#opts + 1] = createElement(OptionButton, {
                    key = "opt_" .. i,
                    letter = letters[i],
                    text = opt,
                    state = state,
                    onPress = function() handleSelect(i) end,
                })
            end
            return opts
        end)()),
        -- Score display
        createElement("View", {
            style = {
                position = "absolute",
                bottom = 40,
                left = 0,
                width = W,
                alignItems = "center",
            },
        },
            createElement("Text", {
                style = {
                    fontSize = 28,
                    color = "#9E9E9E",
                },
            }, "得分: " .. score)
        ),
        -- Result modal
        createElement(ResultModal, {
            visible = showResult,
            score = score,
            total = #QUESTIONS,
            onRetry = handleRetry,
        })
    )
end

return QuizApp
