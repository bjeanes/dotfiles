(require 'cl) ; needed for powerline

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
                      clojure-mode
                      clojure-project-mode
                      autopair
                      ruby-tools
                      ruby-end
                      ruby-electric
                      color-theme
                      color-theme-molokai
                      rainbow-delimiters
                      ctags
                      paredit
                      undo-tree
                      org
                      powerline
                      evil
                      surround)
  "A list of packages to ensure are installed at launch.")

(dolist (p my-packages)
  (when (not (package-installed-p p))
        (package-install p)))
