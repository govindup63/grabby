.PHONY: test build app run probe clean

test:
	swift test

build:
	swift build -c release

app:
	scripts/bundle.sh

run:
	scripts/run-dev.sh

probe:
	swift run grabby-probe --symbols
	swift run grabby-probe --spaces

clean:
	rm -rf .build build
