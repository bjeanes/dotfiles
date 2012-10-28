(require 'ruby-electric)
(require 'ruby-end)
(require 'ruby-tools)

(custom-set-variables '(ruby-end-insert-newline nil)
                      '(ruby-deep-indent-paren nil))

(eval-after-load 'ruby-mode '(progn
                               (add-hook 'ruby-mode-hook
                                         (lambda ()
                                           (subword-mode +1)))))
