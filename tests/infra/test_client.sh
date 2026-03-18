#!/bin/bash
# test_client.sh — Remote test client for Solar2D test server
# Usage: ./test_client.sh [command] [args]

HOST="http://localhost:9876"

case "$1" in
    status)
        curl -s "$HOST/status" | jq .
        ;;
    run)
        # Usage: ./test_client.sh run [pattern]
        PATTERN="${2:-all}"
        curl -s -X POST "$HOST/run" -d "pattern=$PATTERN" | jq .
        ;;
    exec)
        # Usage: ./test_client.sh exec "print('hello')"
        CODE="$2"
        ENCODED=$(echo -n "$CODE" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read()))")
        curl -s -X POST "$HOST/exec" -d "code=$ENCODED" | jq .
        ;;
    categories)
        curl -s "$HOST/categories" | jq .
        ;;
    tap)
        # Usage: ./test_client.sh tap Forms
        CATEGORY="$2"
        curl -s -X POST "$HOST/tap" -d "category=$CATEGORY" | jq .
        ;;
    nav)
        # Usage: ./test_client.sh nav quiz
        ROUTE="$2"
        curl -s -X POST "$HOST/navigate" -d "route=$ROUTE" | jq .
        ;;
    *)
        echo "Usage: $0 {status|run|exec|categories|tap|nav}"
        echo ""
        echo "Commands:"
        echo "  status              - Check server status"
        echo "  run [pattern]       - Run tests (default: all)"
        echo "  exec 'lua code'     - Execute Lua code"
        echo "  categories          - List KitchenSink categories"
        echo "  tap <category>      - Tap a category button"
        echo "  nav <route>         - Navigate to route"
        echo ""
        echo "Examples:"
        echo "  $0 run pressable"
        echo "  $0 tap Forms"
        echo "  $0 exec \"print('Hello from remote')\""
        ;;
esac
