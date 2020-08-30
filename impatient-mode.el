;;; impatient-mode.el --- Serve buffers live over HTTP -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Author: Brian Taylor <el.wubo@gmail.com>
;; Version: 1.1
;; URL: https://github.com/netguy204/imp.el
;; Package-Requires: ((emacs "24.3") (simple-httpd "1.5.0"))

;;; Commentary:

;; impatient-mode is a minor mode that publishes the live buffer
;; through the local simple-httpd server under /imp/live/<buffer-name>/.
;; To unpublish a buffer, toggle impatient-mode off.

;; Start the simple-httpd server (`httpd-start') and visit /imp/ on
;; the local server.  There will be a listing of all the buffers that
;; currently have impatient-mode enabled.  This is likely to be found
;; here:

;;   http://localhost:8080/imp/

;; To receive updates the browser issues a long poll on the client
;; waiting for the buffer to change -- server push.  The response
;; happens in an `after-change-functions' hook.  Buffers that do not
;; run these hooks will not be displayed live to clients.

;;; Code:

(require 'cl-lib)
(require 'url-util)
(require 'simple-httpd)

(defgroup impatient nil
  "Serve buffers live over HTTP."
  :group 'comm)

(defcustom impatient-mode-delay nil
  "The delay in seconds between a keypress and the browser reload.
Set to nil for no delay"
  :group 'impatient
  :type 'boolean)

(defcustom imp-default-user-filters '((mhtml-mode . nil)
                                      (html-mode . nil)
                                      (web-mode . nil)
                                      (markdown-mode . imp-markdown-filter))
  "Alist indicating which filter should be used for which modes."
  :group 'impatient
  :type 'sexp)

(defcustom imp-new-template
  "Markdown document
=================

# Installation

1. aa

2. bb

# Using

* settings

  ```lisp
  (setq foo \"bar\")  ; comment
  ```

* bb

  | a1 | b1 | c1 | d1 |
  |----|----|----|----|
  | a2 | b2 | c2 | d2 |
  | a3 | b3 | c3 | d3 |

# Security

  - [x] aabbcc
  - [ ] ddeeff

# etc

```mermaid
gantt
  title mermaid.js
  dateFormat YYYY-MM-DD

  section planning
    html: p1, 2020-08-20, 30m
    js: p2, after p1, 1h
    el: p3, after p2, 1h

  section coding
    html: c1,after p3 , 30m
    js: c2, after c1, 1h
    el: c3, after c2, 1h
```

"
 "Strings of template for new document."
  :group 'impatient
  :type 'string)

(defcustom imp-xwidget-webkit-display-side 'right
  ""
  :group 'impatient
  :type '(choice (const left)
                 (const right)))

(defcustom imp-xwidget-webkit-display-ratio 0.5
  ""
  :group 'impatient
  :type 'number)

(defvar-local imp--idle-timer nil
  "A timer that goes off after `impatient-mode-delay' seconds of inactivity")

(defvar-local imp-client-list ()
  "List of client processes watching the current buffer.")

(defvar-local imp-last-state 0
  "State sequence number.")

(defvar-local imp-related-files nil
  "Files that seem to be related to this buffer")

(defvar-local imp--buffer-dirty-p nil
  "If non-nil, buffer has been modified but not sent to clients.")

(defvar impatient-mode-map (make-sparse-keymap)
  "Keymap for impatient-mode.")

(defconst imp--enable-xwidget-webkit--p
  (and window-system
       (featurep 'xwidget-internal))
  "If non-nil, enabled xwidget-webkit.")

(defvar imp-browser-scroll-lines 3)

(defun imp-browser-scroll-up-line (direction)
  (cl-incf imp-last-state)
  (while imp-client-list
    (imp--send-state (pop imp-client-list)
                     (format "Scroll/%s" (* direction imp-browser-scroll-lines)))))


(defun imp-browser-scrollto (pos)
  (cl-incf imp-last-state)
  (while imp-client-list
    (imp--send-state (pop imp-client-list)
                     (format "Goto/%s" pos))))

(defun imp-browser-recenter (pos)
  (cl-incf imp-last-state)
  (while imp-client-list
    (imp--send-state (pop imp-client-list)
                     (format "Recenter/%s" pos))))

(defun get-pos ()
  (format "0.%d" (* 100 (/ (float (point))
                         (float (save-excursion (end-of-buffer) (point)))))))

(let ((map impatient-mode-map))
  (define-key map (kbd "M-<")
    (lambda () (interactive) (imp-browser-scrollto "Top") (beginning-of-buffer)))
  (define-key map (kbd "M->")
    (lambda () (interactive) (imp-browser-scrollto "bottom") (end-of-buffer)))
  (define-key map (kbd "C-l")
    (lambda () (interactive) (imp-browser-recenter (get-pos)) (recenter-top-bottom)))

  (cond (imp--enable-xwidget-webkit--p
         (define-key map (kbd "C-<down>")
           (lambda () (interactive) (xwidget-webkit-scroll-up-line  1)))
         (define-key map (kbd "C-<up>")
           (lambda () (interactive) (xwidget-webkit-scroll-up-line -1)))
         (define-key map (kbd "<f5>")
           (lambda () (interactive) (xwidget-webkit-reload))))

        (t
         (define-key map (kbd "M-n")
           (lambda () (interactive) (imp-browser-scroll-up-line  1)))
         (define-key map (kbd "M-p")
           (lambda () (interactive) (imp-browser-scroll-up-line -1)))
         )))

(defun imp--clear-buffer-modified ()
  (let ((xwb (imp--xwidget-webkit-buffer)))
    (when xwb
      (dolist (b xwb)
        (set-buffer b)
        (set-buffer-modified-p nil)))))

(add-hook 'kill-emacs-hook #'imp--clear-buffer-modified)

;;;###autoload
(define-minor-mode impatient-mode
  "Serves the buffer live over HTTP."
  :group 'impatient
  :lighter " imp"
  :keymap impatient-mode-map
  (if (not impatient-mode)              ; executed after toggling the mode
      ;; t-> nil
      (progn
        (imp--cleanup-timer)
        (remove-hook 'after-change-functions #'imp--on-change t))
    ;; nil -> t
    (add-hook 'kill-buffer-hook #'imp--cleanup-timer nil t)
    (add-hook 'after-change-functions #'imp--on-change nil t)
    (imp-remove-user-filter)))

(defvar imp-shim-root (file-name-directory load-file-name)
  "Location of data files needed by impatient-mode.")

(defun imp-set-user-filter (fn)
  "Set a FN as user-defined filter for this buffer.
FUNCTION should accept one argument, the buffer to be filtered,
and will be evaluated with the output buffer set as the current
buffer."
  (interactive "aCustom filter: ")
  (setq imp-user-filter fn)
  (cl-incf imp-last-state)
  (imp--notify-clients))

(defun imp-remove-user-filter ()
  "Set the user-defined filter for this buffer to the default."
  (interactive)
  (let ((lookup (assoc major-mode imp-default-user-filters)))
    (if lookup
        (imp-set-user-filter (cdr lookup))
      (kill-local-variable 'imp-user-filter)))
  (cl-incf imp-last-state)
  (imp--notify-clients))

(defun imp-markdown-filter (buffer)
  (princ
   (with-current-buffer buffer
     (buffer-substring-no-properties (point-min) (point-max)))
   (current-buffer)))

(defun imp--xwidget-webkit-buffer ()
  (let (r)
    (dolist (b (buffer-list))
      (with-current-buffer b
        (when (string= "xwidget-webkit" (format "%s" mode-name))
          (setq r (cons (buffer-name) r)))))
    r))

(defun imp-visit-buffer (&optional arg)
  "Visit the current buffer in a browser.
If given a prefix ARG, visit the buffer listing instead."
  (interactive "P")
  (unless (process-status "httpd")
    (httpd-start))
  (unless impatient-mode
    (impatient-mode))
  (let* ((proc (get-process "httpd"))
         (proc-info (process-contact proc t))
         (raw-host (plist-get proc-info :host))
         (host (if (member raw-host
                           '(nil local "127.0.0.1" "::1" "0.0.0.0" "::"))
                   "localhost"
                 raw-host))
         (local-addr (plist-get proc-info :local))
         (port (aref local-addr (1- (length local-addr))))
         (url (format "http://%s:%d/imp/" host port)))
    (unless arg
      (setq url (format "%slive/%s/" url (url-hexify-string (buffer-name)))))

    (if imp--enable-xwidget-webkit--p
        (let ((buf (current-buffer)))
          (xwidget-webkit-browse-url url)
          (set-window-buffer (selected-window) buf)
          (display-buffer-in-side-window (get-buffer (car (imp--xwidget-webkit-buffer)))
                                         `((side . ,imp-xwidget-webkit-display-side)
                                           (window-width . (* (frame-width) imp-xwidget-webkit-display-ratio)))))
      (browse-url url))))

;;;###autoload
(defun imp-new ()
  (interactive)
  (let ((buffer (get-buffer-create (format "%s.SureSave.md" (make-temp-name "")))))
    (with-current-buffer buffer
      (insert imp-new-template)
      (goto-char (point-min))
      (markdown-mode)
      (switch-to-buffer buffer))))

(defun imp-buffer-enabled-p (buffer)
  "Return t if BUFFER has impatient-mode enabled."
  (and buffer (with-current-buffer (get-buffer buffer) impatient-mode)))

(defun imp--buffer-list ()
  "List of all buffers with impatient-mode enabled."
  (cl-remove-if-not 'imp-buffer-enabled-p (buffer-list)))

(defun imp--should-not-cache-p (path)
  "True if the PATH should be stamped with a no-cache header."
  (let ((mime-type (httpd-get-mime (file-name-extension path))))
    (member mime-type '("text/css" "text/html" "text/xml"
                        "text/plain" "text/javascript"))))

(defun httpd/imp/static (proc path _query req)
  "Serve up static files."
  (let* ((file (file-name-nondirectory path))
         (clean (expand-file-name file imp-shim-root)))
    (if (file-exists-p clean)
        (httpd-send-file proc clean req)
      (httpd-error proc 404))))

(defun imp-serve-buffer-list (proc)
  "Serve a list of published buffers."
  (with-httpd-buffer proc "text/html; charset=utf-8"
    (insert "<html><head>\n")
    (insert "<title>impatient-mode buffer list</title>\n")
    (insert "<style>li{transition:background-color 0.3s linear;}\n")
    (insert "li:hover{background-color:yellow;}</style>\n")
    (insert "</head><body>\n")
    (insert "<h1>Public Buffers</h1>\n<hr/>")
    (insert "<ul>\n")
    (dolist (buffer (imp--buffer-list))
      (insert (format "<li><a href=\"live/%s/\">%s</a></li>\n"
                      (url-hexify-string (buffer-name buffer))
                      (url-insert-entities-in-string (buffer-name buffer)))))
    (insert "</ul>\n<hr/>")
    (insert "Enable <code>impatient-mode</code> in buffers to publish them.")
    (insert "</body></html>")))

(defun imp--private (proc buffer-name)
  (httpd-error proc 403
               (format "Buffer %s is private or doesn't exist." buffer-name)))

(defun httpd/imp/live (proc path _query req)
  "Serve up the shim that lets us watch a buffer change."
  (let* ((index (expand-file-name "index.html" imp-shim-root))
         (decoded (url-unhex-string path))
         (parts (cdr (split-string decoded "/")))
         (buffer-name (nth 2 parts))
         (file (httpd-clean-path (mapconcat 'identity (nthcdr 3 parts) "/")))
         (buffer (get-buffer buffer-name))
         (buffer-file (buffer-file-name buffer))
         (buffer-dir (and buffer-file (file-name-directory buffer-file))))

    (cond
     ((equal (file-name-directory decoded) "/imp/live/")
      (httpd-redirect proc (concat decoded "/")))
     ((not (imp-buffer-enabled-p buffer)) (imp--private proc buffer-name))
     ((and (not (string= file "./")) buffer-dir)
      (let* ((full-file-name (expand-file-name file buffer-dir))
             (mime-type (httpd-get-mime (file-name-extension full-file-name)))
             (live-buffer (cl-remove-if-not
                           (lambda (buf) (equal full-file-name (buffer-file-name buf)))
                           (imp--buffer-list))))
        (with-current-buffer buffer-name
          (add-to-list 'imp-related-files full-file-name))
        (if live-buffer
            (with-temp-buffer
              (insert-buffer-substring (cl-first live-buffer))
              (if (imp--should-not-cache-p decoded)
                  (httpd-send-header proc mime-type 200
                                     :Cache-Control "no-cache")
                (httpd-send-header proc mime-type 200
                                   :Cache-Control
                                   "max-age=60, must-revalidate")))
          (httpd-send-file proc full-file-name req))))
     (t (httpd-send-file proc index req)))))

(defun httpd/imp (proc path &rest _)
  (cond
   ((equal path "/imp")  (httpd-redirect proc "/imp/"))
   ((equal path "/imp/") (imp-serve-buffer-list proc))
   (t (httpd-error proc 403 (format "%s not found" path)))))

(defun imp--send-state (proc &optional props)
  (let ((id (number-to-string imp-last-state))
        (user-filter imp-user-filter)
        (buffer (current-buffer)))
    (with-temp-buffer
      (let ((standard-output (current-buffer)))
        (if user-filter
            (funcall user-filter buffer)
          (insert-buffer-substring buffer))
        (httpd-send-header proc "text/html" 200
                           :Cache-Control "no-cache"
                           :X-Imp-Ctrl props
                           :X-Imp-Count id)))))

(defun imp--send-state-ignore-errors (proc)
  (condition-case _
      (imp--send-state proc)
    (error nil)))

(defun imp--notify-clients ()
  (while imp-client-list
    (imp--send-state-ignore-errors (pop imp-client-list))))

(defun imp--cleanup-timer ()
  "Destroy any timer associated with this buffer."
  (when imp--idle-timer
    (cancel-timer (cdr imp--idle-timer))
    (setf imp--idle-timer nil)))

(defun imp--start-idle-timer ()
  "Start/update the idle timer as appropriate."
  (cond
   ;; Timer doesn't exist and shouldn't (do nothing)
   ((and (null impatient-mode-delay) (null imp--idle-timer)))
   ;; Timer exists when it shouldnt
   ((and (null impatient-mode-delay) imp--idle-timer)
    (cancel-timer (cdr imp--idle-timer))
    (setf imp--idle-timer nil))
   ;; Timer doesn't exist when it should
   ((and impatient-mode-delay (null imp--idle-timer))
    (let* ((buffer (current-buffer))
           (timer (run-with-idle-timer
                   impatient-mode-delay :repeat
                   (lambda ()
                     (with-current-buffer buffer
                       (imp--after-timeout))))))
      (setf imp--idle-timer (cons impatient-mode-delay timer))))
   ;; Timer delay is incorrect
   ((not (eql (car imp--idle-timer) impatient-mode-delay))
    (timer-set-idle-time (cdr imp--idle-timer)
                         impatient-mode-delay
                         :repeat)
    (setf (car imp--idle-timer) impatient-mode-delay))))

(defun imp--on-change (&rest _)
  "Hook for `after-change-functions'."
  (imp--start-idle-timer)
  (if impatient-mode-delay
      (setf imp--buffer-dirty-p :dirty)
    (imp--update-buffer)))

(defun imp--after-timeout ()
  "Execute after `impatient-mode-delay' seconds of idleness."
  (when imp--buffer-dirty-p
    (imp--update-buffer))
  (imp--start-idle-timer))

(defun imp--update-buffer ()
  "Update this buffer in the browser."
  (setf imp--buffer-dirty-p nil)
  (cl-incf imp-last-state)
  ;; notify our clients
  (imp--notify-clients)
  ;; notify any clients that we're in the `imp-related-files' list for
  (let ((buffer-file (buffer-file-name (current-buffer))))
    (dolist (buffer (imp--buffer-list))
      (with-current-buffer buffer
        (when (member buffer-file imp-related-files)
          (imp--notify-clients))))))

;; Called from Javascript function refresh().
(defun httpd/imp/buffer (proc path query &rest _)
  "Servlet that accepts long poll requests."
  (let* ((decoded (url-unhex-string path))
         (buffer-name (file-name-nondirectory decoded))
         (buffer (get-buffer buffer-name))
         (req-last-id (string-to-number (or (cadr (assoc "id" query)) "0"))))
    (if (imp-buffer-enabled-p buffer)
        (with-current-buffer buffer
          (if (equal req-last-id imp-last-state)
              (push proc imp-client-list)         ; this client is sync'd
            (imp--send-state-ignore-errors proc))) ; this client is behind
      (imp--private proc buffer-name))))

(provide 'impatient-mode)

;;; impatient-mode.el ends here
