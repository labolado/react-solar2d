# React-Solar2D iOS device build
# Copy Makefile.local.example to Makefile.local and fill in your values
-include Makefile.local

CORONA_BUILDER ?= /Applications/Corona/Native/Corona/mac/bin/CoronaBuilder.app/Contents/MacOS/CoronaBuilder
BUILD_DIR ?= /tmp/react-solar2d-build
APP_NAME ?= ReactSolar2D

.PHONY: device install build resign uninstall test

# Build + sign + install to device (one command)
device: build resign install
	@echo "Done. Live Build active — edit Lua files and they sync to device."

build:
	@rm -rf $(BUILD_DIR) && mkdir -p $(BUILD_DIR)
	@echo 'local p={platform="ios",appName="$(APP_NAME)",appVersion="1.0",dstPath="$(BUILD_DIR)",projectPath="$(CURDIR)/",certificatePath="$(PROFILE)",targetDevice="iphone",liveBuild=true} return p' > /tmp/_build.lua
	$(CORONA_BUILDER) build --lua /tmp/_build.lua

resign:
	@echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>application-identifier</key><string>$(TEAM_ID).$(BUNDLE_ID)</string><key>com.apple.developer.team-identifier</key><string>$(TEAM_ID)</string><key>get-task-allow</key><true/><key>keychain-access-groups</key><array><string>$(TEAM_ID).$(BUNDLE_ID)</string></array></dict></plist>' > /tmp/_ent.plist
	codesign -f -s "$(SIGN_ID)" --entitlements /tmp/_ent.plist $(BUILD_DIR)/$(APP_NAME).app

install:
	xcrun devicectl device install app --device $(DEVICE) $(BUILD_DIR)/$(APP_NAME).app

uninstall:
	xcrun devicectl device uninstall app --device $(DEVICE) $(BUNDLE_ID)

test:
	lua run_tests.lua
