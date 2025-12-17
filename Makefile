SHELL := /bin/bash

.PHONY: release clean
release:
	./scripts/build_release.sh

clean:
	bash ./scripts/clean.sh
