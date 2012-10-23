(require 'evil)
(add-hook 'prog-mode-hook 'evil-mode)

(define-key evil-motion-state-map (kbd "C-u") 'evil-scroll-up)

;; TODO
;; * Map D to C-k (i.e. preserve paredit's version)
;; * Make word motions obey subword-mode setting
;; * Put current Evil state into powerline
