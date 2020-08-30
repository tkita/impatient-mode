Impatient Mode
==============

_This version is for markdown only._

## Screenshots

 * realtime previewing by firefox.

 [<img src="https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/firefox.jpg" width="50%">](https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/firefox.jpg)

 * realtime previewing other buffer by _xwidget-webkit_.

 [<img src="https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/xwidget.jpg" width="50%">](https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/xwidget.jpg)

 * on MS Windows

 [<img src="https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/mswindows.jpg" width="50%">](https://raw.githubusercontent.com/tkita/impatient-mode/screenshots/mswindows.jpg)

## Installation

This version requires _simple-httpd.el_ , _marked.js_ , _github-markdown.css_ and
_mermaid.js_ .
Put follow files in the same directory.

- simple-httpd.el

  * https://github.com/skeeto/emacs-http-server

- marked.js

  * https://github.com/markedjs/marked

- github-markdown.css

  * https://github.com/sindresorhus/github-markdown-css

- mermaid.js

  * https://github.com/mermaid-js/mermaid

or, run command `make get`

```shell
$ make get
```

Add _impatient-mode_ to your load path and require it:

```lisp
  (add-to-list 'load-path "~/.emacs.d/impatient-mode")
  (require 'impatient-mode)
```

## Using _impatient-mode_

* Open markdown file with emacs, and edit buffer.

  or execute command `M-x imp-new`.

* Publish buffers for browser-preview,

  ```
  M-x imp-visit-buffer
  ```

  - previewing web browser specified by variable `browse-url-browser-function`.

    Even better if you set the keymap in markdown mode.

    ```lisp
    (define-key markdown-mode-map (kbd "&lt;f12&gt;") 'imp-visit-buffer)
    ```

  - If emacs builded configure option `--with-xwidgets`, previewing in other buffer by _xwidget-webkit_ on emacs.

    ```
    system-configuration-options [C-j]
    => "--with-xwidgets"
    ```

* key operation of emacs also works with web browser via http-header `X-Imp-Ctrl:`.

  - common

    | impatient-mode/emacs      | xwidget-webkit, web browser                                                  |
    |---------------------------|------------------------------------------------------------------------------|
    | M-< (beginning-of-buffer) | window.scrollTo( 0, 0 );                                                     |
    | M-> (end-of-buffer)       | window.scrollTo( 0, bottom );                                                |
    | C-l (recenter-top-bottom) | window.scrollTo( 0, documentElement.scrollHeight * (/ (point) (point-max))); |

  - xwidget-webkit

    | impatient-mode/emacs | xwidget-webkit-mode/emacs          |
    |----------------------|------------------------------------|
    | C-&lt;up&gt;         | (xwidget-webkit-scroll-up-line -1) |
    | C-&lt;down&gt;       | (xwidget-webkit-scroll-up-line 1)  |

  - other browser

    | impatient-mode/emacs                | web browser                                            |
    |-------------------------------------|--------------------------------------------------------|
    | M-p (imp-browser-scroll-up-line -1) | window.scrollByLines( -1 * imp-browser-scroll-lines ); |
    | M-n (imp-browser-scroll-up-line 1)  | window.scrollByLines( imp-browser-scroll-lines );      |
