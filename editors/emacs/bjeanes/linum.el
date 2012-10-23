(global-linum-mode t)

;; From http://www.emacswiki.org/LineNumbers
(setq linum-format
      (lambda (line)
        (propertize
         (format (let ((w (length (number-to-string
                                   (count-lines (point-min)
                                                (point-max))))))
                   (concat "%"
                           (number-to-string w) "d "))
                 line)
         'face
         'linum)))
