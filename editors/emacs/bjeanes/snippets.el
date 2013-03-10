(require 'yasnippet)

(add-to-list 'yas-snippet-dirs
             (concat esk-user-dir "/snippets"))

(yas-reload-all)

(add-hook 'prog-mode-hook 'yas-minor-mode)
