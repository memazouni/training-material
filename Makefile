# Settings
JEKYLL=bundle exec jekyll
CHROME=google-chrome-stable
DECKTAPE_VERSION=1.0.0
DECKTAPE_DIR=decktape-$(DECKTAPE_VERSION)
PHANTOMJS_BIN=https://github.com/astefanutti/decktape/releases/download/v$(DECKTAPE_VERSION)/phantomjs-linux-x86-64
DECKTAPE_ARCHIVE=https://github.com/astefanutti/decktape/archive/v$(DECKTAPE_VERSION).tar.gz
TUTORIALS=$(shell find _site/training-material -name 'tutorial.html' | sed 's/_site\/training-material\///')
SLIDES=$(shell find _site/training-material -name 'slides.html' | sed 's/_site\/training-material\///')
SLIDES+=$(shell find _site/training-material/*/*/slides/* | sed 's/_site\/training-material\///')
SITE_URL=http://localhost:4000/training-material
PDF_DIR=_pdf

ifeq ($(shell uname -s),Darwin)
	CHROME=/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome
	PHANTOMJS_BIN=https://github.com/astefanutti/decktape/releases/download/v1.0.0/phantomjs-osx-cocoa-x86-64
endif

default: help

serve: ## run a local server
	${JEKYLL} serve -d _site/training-material
.PHONY: serve

detached-serve: clean ## run a local server in detached mode
	${JEKYLL} serve --detach -d _site/training-material
.PHONY: detached-serve

build: clean ## build files but do not run a server
	${JEKYLL} build -d _site/training-material
.PHONY: build

check-html: build ## validate HTML
	bundle exec htmlproofer --http-status-ignore 405,999 --url-ignore "/.*localhost.*/","/.*vimeo\.com.*/" --file-ignore "/.*\/files\/.*/" ./_site
.PHONY: check-html

check-links-gh-pages:  ## validate HTML on gh-pages branch (for daily cron job)
	bundle exec htmlproofer --http-status-ignore 405,999 --url-ignore "/.*localhost.*/","/.*vimeo\.com.*/" --file-ignore "/.*\/files\/.*/" .
	find . -path "**/slides*.html" | xargs -L 1 -I '{}' sh -c "awesome_bot --allow 405 --allow-redirect --white-list localhost,127.0.0.1,fqdn --allow-ssl --allow-dupe --skip-save-results -f {}"
.PHONY: check-links-gh-pages

check-yaml: ## lint yaml files
	yamllint .
.PHONY: check-yaml

check-slides: build  ## check the markdown-formatted links in slides
	find _site -path "**/slides*.html" | xargs -L 1 -I '{}' sh -c "awesome_bot --allow 405 --allow-redirect --white-list localhost,127.0.0.1,fqdn --allow-ssl --allow-dupe --skip-save-results -f {}"
.PHONY: check-slides

check: check-yaml check-html check-slides  ## run all checks
.PHONY: check

clean: ## clean up junk files
	@rm -rf _site
	@rm -rf .sass-cache
	@find . -name .DS_Store -exec rm {} \;
	@find . -name '*~' -exec rm {} \;
.PHONY: clean

install: ## install dependencies
	gem install bundler
	bundle install
	bundle update
.PHONY: install

$(DECKTAPE_DIR)/phantomjs:
	curl -L $(DECKTAPE_ARCHIVE) | tar -xz --exclude phantomjs
	curl -L $(PHANTOMJS_BIN) -o $@ && chmod +x $@

install-pdf: $(DECKTAPE_DIR)/phantomjs ## install dependencies for PDF generation
.PHONY: install-pdf

pdf: install-pdf detached-serve ## generate the PDF of the tutorials and slides
	mkdir -p _pdf
	@for t in $(TUTORIALS); do \
		name="$(PDF_DIR)/$$(echo $$t | tr '/' '-' | sed -e 's/html/pdf/' -e 's/topics-//' -e 's/tutorials-//')"; \
		${CHROME} \
            --headless \
            --disable-gpu \
            --print-to-pdf="$$name" \
            "$(SITE_URL)/$$t" \
            2> /dev/null ; \
    done
	@for s in $(SLIDES); do \
		name="$(PDF_DIR)/$$(echo $$s | tr '/' '-' | sed -e 's/html/pdf/' -e 's/topics-//' -e 's/tutorials-//')"; \
		$(DECKTAPE_DIR)/phantomjs \
			$(DECKTAPE_DIR)/decktape.js \
			"$(SITE_URL)/$$s" \
			"$$name" \
            2> /dev/null ; \
	done
.PHONY: pdf

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.PHONY: help
