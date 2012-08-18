(require 'package)
(add-to-list 'package-archives '("marmalade" . "http://marmalade-repo.org/packages/") t)
(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/") t)
(package-initialize)

(when (not package-archive-contents)
  (package-refresh-contents))

;; Add in your own as you wish:
(defvar my-packages '(starter-kit
                      starter-kit-ruby
                      starter-kit-lisp
                      starter-kit-eshell
                      starter-kit-js
                      starter-kit-bindings
                      clojure-mode
                      clojure-project-mode
                      color-theme
                      color-theme-molokai
                      ctags
                      paredit
                      undo-tree
                      org
                      evil)
  "A list of packages to ensure are installed at launch.")

(dolist (p my-packages)
  (when (not (package-installed-p p))
        (package-install p)))

(require 'evil)
(evil-mode 1)

(define-key evil-normal-state-map [escape] 'keyboard-quit)
(define-key evil-visual-state-map [escape] 'keyboard-quit)
(define-key minibuffer-local-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-ns-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-completion-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-must-match-map [escape] 'minibuffer-keyboard-quit)

(defun plist-to-alist (&optional arg) nil) ; stop a weird error coming
                                           ; from color-theme-molokai
(require 'paredit)
(paredit)

(require 'color-theme)
(require 'color-theme-molokai)
(color-theme-molokai)
