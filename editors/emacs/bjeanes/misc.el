(require 'powerline)
(command-execute 'powerline-default-theme)

(global-auto-revert-mode t)

(when (package-installed-p 'markdown-mode)
  (add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
  (add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode)))
