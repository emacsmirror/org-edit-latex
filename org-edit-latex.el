;;; org-edit-latex.el --- Edit LaTeX in a dedicated buffer

;; Copyright (C) 2017-2018 James Wong

;; Author: James Wong <jianwang.academic@gmail.com>
;; URL: https://github.com/et2010/org-edit-latex
;; Keywords: org, LaTeX
;; Version: 0.6.1
;; Package-Requires: ((emacs "24.4"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package will let you edit a latex fragment like editing a src code
;; block.

;; Usage
;; =====

;; First, turn on `org-edit-latex-mode'. Then you can edit a LaTeX fragment just
;; as what you'll do to edit a src block.

;; Use `org-edit-special' to enter a dedicated LaTeX buffer.
;; Use `org-edit-src-exit' to exit LaTeX buffer when you finished editing.
;; Use `org-edit-src-abort' to quit editing without saving changes.

;; Note that all above commands are built-in Org commands, so your current
;; keybindings to them will do the job.

;;; Code:

(require 'org)
(require 'org-element)

(defvar org-edit-latex-edited-element-type nil
  "The type of the edited element.")

;;;###autoload
(define-minor-mode org-edit-latex-mode
  "LaTeX editing in org mode."
  :lighter " Edit-LaTeX"
  (if org-edit-latex-mode
      (progn
        (advice-add #'org-edit-special :around #'org-edit-latex--wrap-maybe)
        (advice-add #'org-edit-src-exit :after #'org-edit-latex--unwrap-maybe '((depth . 100))))
    (advice-remove #'org-edit-special #'org-edit-latex--wrap-maybe)
    (advice-remove #'org-edit-src-exit #'org-edit-latex--unwrap-maybe)))


(defun org-edit-latex--wrap-latex (ele)
  "Wrap latex fragment in a latex src block."
  (let* ((beg (org-element-property :begin ele))
         (end (org-element-property :end ele))
         (nb (org-element-property :post-blank ele))
         (type (save-excursion
                 (goto-char beg)
                 (cond
                  ((looking-at-p "^[ \t]*\\\\begin") 'environment)
                  ((looking-at-p "\\\\(\\|\\$[^$]\\|\\\\\\sw") 'inline)
                  (t nil))))
         (pt (point)))
    (save-excursion
      (cond
       ((eq type 'environment)
        (goto-char end)
        (when (not (and (eobp)
                        (equal 0 nb)
                        (save-excursion
                          (beginning-of-line)
                          (looking-at-p "[ \t]*\\\\end{"))))
          (forward-line (- (1+ nb)))
          (end-of-line))
        (insert "\n#+END_SRC")
        (goto-char beg)
        (insert "#+BEGIN_SRC latex\n"))
       ((eq type 'inline)
        (goto-char (- end nb))
        (insert "}")
        (goto-char beg)
        (insert " src_latex{"))
       (t
        (goto-char end)
        (insert "\n#+END_SRC")
        (goto-char beg)
        (beginning-of-line)
        (insert "#+BEGIN_SRC latex\n"))))
    (when (= pt beg) (goto-char (1+ pt)))))

(defun org-edit-latex--unwrap-latex (ele)
  "Unwrap latex fragment."
  (let* ((lang (org-element-property :language ele))
         (beg (org-element-property :begin ele))
         (end (org-element-property :end ele))
         (nb (org-element-property :post-blank ele))
         (type (car ele)))
    (cond ((eq 'src-block type)
           (save-excursion
             (goto-char end)
             (if (and (eobp)
                      (equal 0 nb)
                      (save-excursion
                        (beginning-of-line)
                        (looking-at-p "#\\+end_src")))
                 (delete-region (point-at-bol) (point-at-eol))
               (forward-line (- (1+ nb)))
               (delete-region (point-at-bol) (1+ (point-at-eol))))
             (goto-char beg)
             (delete-region (point-at-bol) (1+ (point-at-eol)))))
          ;; inline src block
          ((eq 'inline-src-block type)
           (save-excursion
             ;; delete trailing "}"
             (goto-char (- end nb 1))
             (delete-char 1)
             ;; delete " src_block{", note there is a space before "src_block{"
             (goto-char (1- beg))
             (delete-char 11)))
          (t nil))))

(defun org-edit-latex--unwrap-maybe (&rest args)
  "Unwrap latex fragment only if it meets certain predicates."
  (when (and org-edit-latex-mode
             (memq org-edit-latex-edited-element-type
                   '(latex-fragment latex-environment)))
    (let* ((ele (org-element-context))
           (type (car ele))
           (lang (org-element-property :language ele))
           (beg (org-element-property :begin ele)))
      (and (equal "latex" lang)
           (or (and (eq 'src-block type)
                    (save-excursion
                      (goto-char beg)
                      (looking-at-p "^#\\+begin_src latex$")))
               (and (eq 'inline-src-block type)
                    (save-excursion
                      (goto-char beg)
                      (looking-at-p "src_latex{"))))
           (org-edit-latex--unwrap-latex ele)))))

(defun org-edit-latex--wrap-maybe (oldfun &rest args)
  "Wrap element at point if its type is latex-fragment or
latex-environment.

Returns element type at point."
  (let* ((ele (org-element-context))
         (type (car ele)))
    (if (and org-edit-latex-mode
             (memq type '(latex-fragment latex-environment)))
        (progn
          (org-edit-latex--wrap-latex ele)
          (let ((org-src-preserve-indentation t))
            (apply oldfun args)))
      (apply oldfun args))
    (setq org-edit-latex-edited-element-type type)))


(provide 'org-edit-latex)
;;; org-edit-latex.el ends here
