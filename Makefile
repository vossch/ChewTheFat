# ChewTheFat — dev tooling Makefile.
# Xcode builds via the app's scheme; this Makefile is for repo-wide tasks.

.PHONY: help db-refresh db-verify db-clean

help:
	@echo "Targets:"
	@echo "  db-refresh  Download USDA + OFFs sources and rebuild ChewTheFat/Resources/*.sqlite"
	@echo "  db-verify   Smoke-check the bundled reference databases"
	@echo "  db-clean    Remove generated *.sqlite files (leaves sources in place)"

db-refresh:
	Tools/db-prep/fetch_sources.sh
	python3 Tools/db-prep/prepare.py
	python3 Tools/db-prep/verify.py

db-verify:
	python3 Tools/db-prep/verify.py

db-clean:
	rm -f ChewTheFat/Resources/usda.sqlite ChewTheFat/Resources/offs.sqlite
