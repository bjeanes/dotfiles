(defun plist-to-alist (&optional arg) nil) ; stop a weird error coming
                                           ; from color-theme-molokai
(require 'color-theme)
(require 'color-theme-molokai)
(color-theme-molokai)

(set-face-background 'hl-line "#000")
