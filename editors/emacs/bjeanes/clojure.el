(require 'clojure-mode)
(define-clojure-indent
  (defroutes 'defun)
  (do-seq 1)
  (GET 2)
  (POST 2)
  (PUT 2)
  (DELETE 2)
  (HEAD 2)
  (ANY 2)
  (context 2))

(require 'nrepl)
(add-hook 'nrepl-interaction-mode-hook
          'nrepl-turn-on-eldoc-mode)
(setq nrepl-popup-stacktraces nil)
