;; TODO
;; * Map D to C-k (i.e. preserve paredit's version)
;; * Make word motions obey subword-mode setting
;; * Put current Evil state into powerline

(require 'evil)

;; This is actually mapped but it doesn't seem to work reliably
;; without this
(define-key evil-motion-state-map (kbd "C-u") 'evil-scroll-up)

;; Escape quits
;; https://github.com/mbriggs/.emacs.d/blob/d9e254ae/my-keymaps.el#L81-L89
(define-key evil-normal-state-map [escape] 'keyboard-quit)
(define-key evil-visual-state-map [escape] 'keyboard-quit)
(define-key minibuffer-local-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-ns-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-completion-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-must-match-map [escape] 'minibuffer-keyboard-quit)
(define-key minibuffer-local-isearch-map [escape] 'minibuffer-keyboard-quit)


(require 'cl) ; for `flet`
(flet ((move-key (keymap-from keymap-to key)
                   (define-key keymap-to key (lookup-key keymap-from key))
                   (define-key keymap-from key nil)))
  ;; Keep space/return available for other modes
  ;; http://emacswiki.org/emacs/Evil#toc11
  (move-key evil-motion-state-map evil-normal-state-map (kbd "RET"))
  (move-key evil-motion-state-map evil-normal-state-map " "))

;; a la vim-surround
(require 'surround)
(add-hook 'prog-mode-hook
          (lambda ()
            (turn-on-evil-mode)
            (turn-on-surround-mode)))

;; "tabs" (http://emacswiki.org/emacs/Evil#toc16)
(load "elscreen" "ElScreen" t)
(define-key evil-normal-state-map (kbd "C-w t") 'elscreen-create) ;create tab
(define-key evil-normal-state-map (kbd "C-w x") 'elscreen-kill) ;kill tab
(define-key evil-normal-state-map "gT" 'elscreen-previous) ;previous tab
(define-key evil-normal-state-map "gt" 'elscreen-next) ;next tab

(require 'evil-paredit)
(add-hook 'emacs-lisp-mode-hook 'evil-paredit-mode)
(add-hook 'clojure-mode-hook 'evil-paredit-mode)
(add-hook 'common-lisp-mode-hook 'evil-paredit-mode)
(add-hook 'scheme-mode-hook 'evil-paredit-mode)
(add-hook 'lisp-mode-hook 'evil-paredit-mode)
