(add-hook 'prog-mode-hook
          (lambda ()
            (flyspell-prog-mode)
            (whitespace-mode +1)

            (require 'autopair)
            (autopair-mode 1)

            (define-key global-map (kbd "RET") 'newline-and-indent)

            (add-hook 'before-save-hook
                      (lambda ()
                        (gofmt-before-save)
                        (delete-trailing-whitespace)))

            (require 'auto-complete-config)
            (ac-config-default)))


;;;;;;;; misc

;; Auto-compile is really annoying if you have an existing
;; compilation process that puts the output elsewhere or names it
;; differently (e.g. Rails asset pipeline, Middleman, etc)
(setq scss-compile-at-save nil)
