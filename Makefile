# Clone the two dependencies of this package in sibling directories:
#   $ git clone https://github.com/hniksic/emacs-htmlize ../htmlize
#   $ git clone https://github.com/skeeto/emacs-web-server ../simple-httpd
#
# Or set LDFLAGS to point at these packages elsewhere:
#     $ make LDFLAGS='-L path/to/htmlize -L path/to/simple-httpd'
.POSIX:
.SUFFIXES: .el .elc
CURL    = curl -L -o
EMACS   = emacs
LDFLAGS = -L ../simple-httpd -L ../htmlize
VERSION = 1.1
GITHUB  = https://raw.githubusercontent.com

DIST = README.md index.html index.css impatient-mode.js

all: compile

compile: impatient-mode.elc

package: impatient-mode-$(VERSION).tar

impatient-mode-$(VERSION).tar: impatient-mode.el $(DIST)
	rm -rf impatient-mode-$(VERSION)/
	mkdir impatient-mode-$(VERSION)/
	cp impatient-mode.el $(DIST) impatient-mode-$(VERSION)/
	tar cf $@ impatient-mode-$(VERSION)/
	rm -rf impatient-mode-$(VERSION)/

clean:
	rm -f impatient-mode-$(VERSION).tar impatient-mode.elc

run: impatient-mode.elc
	$(EMACS) -Q $(LDFLAGS) -l impatient-mode.elc \
		 impatient-mode.el \
		 -f impatient-mode -f httpd-start

.el.elc:
	$(EMACS) -Q -batch $(LDFLAGS) -f batch-byte-compile $<

get:
	$(CURL) github-markdown.css $(GITHUB)/sindresorhus/github-markdown-css/gh-pages/github-markdown.css
	$(CURL) marked.min.js      $(GITHUB)/markedjs/marked/master/marked.min.js
	$(CURL) simple-httpd.el    $(GITHUB)/skeeto/emacs-web-server/master/simple-httpd.el
	$(CURL) mermaid.min.js     $(GITHUB)/mermaid-js/mermaid/develop/dist/mermaid.min.js
	$(CURL) mermaid.min.js.map $(GITHUB)/mermaid-js/mermaid/develop/dist/mermaid.min.js.map
