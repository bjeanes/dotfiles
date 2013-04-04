(require 'cl) ; needed for powerline

(require 'package)
(add-to-list 'package-archives '("marmalade" . "http://marmalade-repo.org/packages/") t)
(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/") t)
(package-initialize)

(when (not package-archive-contents)
  (package-refresh-contents))

;; Add in your own as you wish:
(defvar my-packages '(ac-nrepl
                      auto-complete
                      autopair
                      clojure-mode
                      clojure-test-mode
                      clojurescript-mode
                      color-theme
                      color-theme-sanityinc-tomorrow
                      ctags
                      evil
                      evil-paredit
                      exec-path-from-shell
                      find-file-in-repository
                      go-mode
                      markdown-mode
                      paredit
                      powerline
                      rainbow-delimiters
                      ruby-electric
                      ruby-end
                      ruby-tools
                      starter-kit
                      starter-kit-eshell
                      starter-kit-js
                      starter-kit-lisp
                      starter-kit-ruby
                      surround
                      undo-tree
                      yasnippet)
  "A list of packages to ensure are installed at launch.")

(dolist (p my-packages)
  (when (not (package-installed-p p))
        (package-install p)))

;; This takes a really long time because ZSH init scripts are TOO slow!
;; Thoughts:
;;   * Extract a lot of non-interactive ZSH stuff to spawn from
;;     .zshenv and adjust exec-path-from-shell to not start interactive
;;     shell
(when (memq window-system '(mac ns))
  (exec-path-from-shell-initialize))

;; TODO:
;; * Go snippets
;; * Custom ruby/rspec snippetts
;; * proper auto-complete / intellisense
;;   * auto pop-up (~100ms)
;;   * intuitive TAB/ENTER support
;;   * can be backed by REPL, ctags, buffer words, etc
;; * Plug snippets into auto-complete
