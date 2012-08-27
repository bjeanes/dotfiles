;; (defun mac-copy ()
;;   (shell-command-to-string "pbpaste"))

;; (defun mac-paste (text &optional push)
;;   (let ((process-connection-type nil))
;;     (let ((proc (start-process "pbcopy" "*Messages*" "pbcopy")))
;;       (process-send-string proc text)
;;       (process-send-eof proc))))

;; (setq interprogram-cut-function 'mac-paste)
;; (setq interprogram-paste-function 'mac-copy)
