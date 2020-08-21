Impatient Mode
==============

_This version is for markdown only._

## Installation

This version requires _simple-httpd.el_ , _marked.js_ , and _github-markdown.css_ .
Put follow files in the same directory.

- simple-httpd.el

  * https://github.com/skeeto/emacs-http-server

- marked.js

  * https://github.com/markedjs/marked

- github-markdown.css

  * https://github.com/sindresorhus/github-markdown-css

or, you can use _get_ target in _make_ command.

  ```shell
  $ make get
  ```

you can add _impatient-mode_ to your load path and require it:

  ```el
  (add-to-list 'load-path "~/.emacs.d/impatient-mode")
  (require 'impatient-mode)
  ```

## Using _impatient-mode_

* Open markdown file with emacs, and edit buffer.

* Publish buffers for preview,

 ```el
 M-x imp-visit-buffer
 ```
 previewed in web browser specified by variable `browse-url-browser-function`.

* if emacs builded with _xwidget-webkit_, previewed in other buffer on emacs.
