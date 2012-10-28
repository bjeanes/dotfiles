(add-hook 'prog-mode-hook
          (lambda ()
            (flyspell-prog-mode)
            (whitespace-mode +1)

            (require 'autopair)
            (autopair-mode 1)

            (define-key global-map (kbd "RET") 'newline-and-indent)

            ;; TODO: Look into whitespace-cleanup instead?
            (add-hook 'before-save-hook
                      'delete-trailing-whitespace)))
