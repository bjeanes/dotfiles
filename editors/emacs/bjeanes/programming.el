(add-hook 'prog-mode-hook
          (lambda ()
            (flyspell-prog-mode)
            (whitespace-mode +1)

            ;; TODO: Look into whitespace-cleanup instead?
            (add-hook 'before-save-hook
                      'delete-trailing-whitespace)))
