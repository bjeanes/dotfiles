(require 'ruby-electric)
(require 'ruby-end)
(require 'ruby-tools)

(custom-set-variables '(ruby-end-insert-newline nil))

(eval-after-load 'ruby-mode '(progn
                               (add-hook 'ruby-mode-hook
                                         (lambda ()
                                           (subword-mode +1)))))
