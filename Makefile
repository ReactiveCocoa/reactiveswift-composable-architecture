PLATFORM_IOS = iOS Simulator,name=iPhone 11 Pro Max
PLATFORM_MACOS = macOS
PLATFORM_TVOS = tvOS Simulator,name=Apple TV
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 7 (45mm)

default: test-all

test-all: test-library test-examples

test-library:
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_IOS)"
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_MACOS)"
	xcodebuild test \
		-scheme ComposableArchitecture \
		-destination platform="$(PLATFORM_TVOS)"
	xcodebuild \
		-scheme ComposableArchitecture_watchOS \
		-destination platform="$(PLATFORM_WATCHOS)"

DOC_WARNINGS := $(shell xcodebuild clean docbuild \
	-scheme ComposableArchitecture \
	-destination platform="$(PLATFORM_MACOS)" \
	-quiet \
	2>&1 \
	| grep "couldn't be resolved to known documentation" \
	| sed 's|$(PWD)|.|g' \
	| tr '\n' '\1')
test-docs:
	@test "$(DOC_WARNINGS)" = "" \
		|| (echo "xcodebuild docbuild failed:\n\n$(DOC_WARNINGS)" | tr '\1' '\n' \
		&& exit 1)

test-examples:
	for scheme in "CaseStudies (SwiftUI)" "CaseStudies (UIKit)" Search SpeechRecognition TicTacToe Todos VoiceMemos; do \
		xcodebuild test \
			-scheme $$scheme \
			-destination platform="$(PLATFORM_IOS)"; \
	done

benchmark:
	swift run --configuration release \
		swift-composable-architecture-benchmark

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Examples ./Package.swift ./Sources ./Tests

.PHONY: format test
