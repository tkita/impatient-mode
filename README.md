Impatient Mode
==============

_This version is for markdown only._

## Screenshots

 * previewing by firefox.

 [<img src="https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/firefox.jpg" width="50%">](https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/firefox.jpg)

 * previewing other buffer by _xwidget-webkit_.

 [<img src="https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/xwidget.jpg" width="50%">](https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/xwidget.jpg)

## Installation

This version requires _simple-httpd.el_ , _marked.js_ , and _github-markdown.css_ .
Put follow files in the same directory.

- simple-httpd.el

  * https://github.com/skeeto/emacs-http-server

- marked.js

  * https://github.com/markedjs/marked

- github-markdown.css

  * https://github.com/sindresorhus/github-markdown-css

or, run command `make get`

```shell
$ make get
```

Add _impatient-mode_ to your load path and require it:

```el
  (add-to-list 'load-path "~/.emacs.d/impatient-mode")
  (require 'impatient-mode)
```

## Using _impatient-mode_

* Open markdown file with emacs, and edit buffer.

* Publish buffers for browser-preview,

  ```el
  M-x imp-visit-buffer
  ```

 previewing web browser specified by variable `browse-url-browser-function`.

* If emacs builded configure option `--with-xwidgets`, previewing in other buffer on emacs.

  ```el
  system-configuration-options [C-j]
  => "--with-xwidgets"
  ```
