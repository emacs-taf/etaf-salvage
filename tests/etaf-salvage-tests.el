;;; -*- lexical-binding: t; -*-
;;; etaf-salvage-tests.el --- Public Salvage gameplay contracts
;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Code:
(require 'ert)
(require 'etaf-salvage)

(defun etaf-salvage-test--wait (session &optional predicate seconds)
  "Await SESSION and optional PREDICATE for up to SECONDS."
  (let ((end (+ (float-time) (or seconds 10))))
    (while (and (< (float-time) end)
                (not (memq (etaf-gamekit-status session) '(closed failed)))
                (or (memq (etaf-gamekit-status session) '(starting busy))
                    (and predicate (not (funcall predicate)))))
      (accept-process-output nil 0.01)))
  (should (eq (etaf-gamekit-status session) 'ready))
  (when predicate (should (funcall predicate))))

(defun etaf-salvage-test--start ()
  "Start a real independent Godot expedition through GameKit."
  (let ((session (etaf-gamekit-start etaf-salvage-game)))
    (etaf-salvage-test--wait session)
    (should-not (etaf-gamekit-last-error session))
    session))

(defun etaf-salvage-test--close (session)
  "Release SESSION and its buffer."
  (when session
    (etaf-gamekit-close session)
    (kill-buffer (etaf-gamekit-buffer session))))

(defmacro etaf-salvage-test--with-game (name &rest body)
  "Run BODY with a public game bound to NAME and dispose it on every path."
  (declare (indent 1))
  `(let ((,name (etaf-salvage-test--start)))
     (unwind-protect (progn ,@body) (etaf-salvage-test--close ,name))))

(defun etaf-salvage-test--act (session operation &optional arguments)
  "Submit OPERATION, wait for its acknowledgment and read its observation."
  (etaf-gamekit-action session operation arguments)
  (etaf-salvage-test--wait session)
  (etaf-gamekit-observation session))

(defun etaf-salvage-test--value (session section key)
  "Read public KEY in SECTION of SESSION's observation."
  (plist-get (plist-get (etaf-gamekit-observation session) section) key))

(defun etaf-salvage-test--pilot (observation)
  "Read the publicly observed pilot entity in OBSERVATION."
  (cl-find "pilot" (plist-get (plist-get observation :world) :entities)
           :key (lambda (entity) (plist-get entity :kind)) :test #'equal))

(ert-deftest etaf-salvage-ui-routes-input-to-native-rules ()
  "Map activation publishes a native path and resizing preserves map dimensions."
  (etaf-salvage-test--with-game session
    (let ((runtime (etaf-runtime-for-buffer (etaf-gamekit-buffer session))))
      (etaf-runtime-refit runtime 1200 46)
      (etaf-salvage-test--wait session (lambda () (etaf-host-ref-size runtime 'salvage-map)))
      (let ((size (etaf-host-ref-size runtime 'salvage-map)))
        (etaf-dispatch-event runtime 'salvage-tile-4-6 'press)
        (etaf-salvage-test--wait session
          (lambda () (equal (car (last (plist-get (etaf-gamekit-view session :world) :route))) '(6 4))))
        (dolist (rows '(70 46 34))
          (etaf-runtime-refit runtime 900 rows)
          (let* ((table (etaf-host-ref-size runtime 'salvage-root))
                 (bounds (etaf-host-ref-bounds runtime 'salvage-root))
                 (surplus (max 0 (- rows (cdr table))))
                 (top (with-current-buffer (etaf-gamekit-buffer session)
                        (1- (line-number-at-pos (car bounds))))))
            (should (<= (abs (- top (* 0.4 surplus))) 1)))
          (let ((map-size (etaf-host-ref-size runtime 'salvage-map)))
            (should (equal size map-size))))))))

(ert-deftest etaf-salvage-themes-preserve-the-expedition ()
  "Light/dark switching preserves the world, route and fixed canvas metrics."
  (etaf-salvage-test--with-game session
    (let ((runtime (etaf-runtime-for-buffer (etaf-gamekit-buffer session))))
      (etaf-runtime-refit runtime 1200 46)
      (etaf-salvage-test--wait session (lambda () (etaf-host-ref-size runtime 'salvage-map)))
      (etaf-dispatch-event runtime 'salvage-tile-4-6 'press)
      (etaf-salvage-test--wait session
        (lambda () (equal (car (last (plist-get (etaf-gamekit-view session :world) :route))) '(6 4))))
      (let ((before (etaf-gamekit-observation session))
            (size (etaf-host-ref-size runtime 'salvage-map)))
        (dotimes (_ 2)
          (etaf-dispatch-event runtime 'salvage-theme 'press)
          (should (equal before (etaf-gamekit-observation session)))
          (should (equal size (etaf-host-ref-size runtime 'salvage-map))))
        (should-not (etaf-gamekit-last-error session))))))

(ert-deftest etaf-salvage-invalid-actions-preserve-the-world ()
  "Invalid coordinates, blocked tiles and bad paths cannot change a paused world."
  (etaf-salvage-test--with-game session
    (let ((before (etaf-gamekit-observation session)))
      (dolist (action '(("navigate" :x 9 :y 1) ("move" :x 1 :y 1)
                        ("move" :x 1.5 :y 0) ("navigate" :x "bad" :y 4)
                        ("load" :path 12) ("repair")))
        (let ((after (etaf-salvage-test--act session (car action) (cdr action))))
          (should (equal before after))
          (should (etaf-gamekit-last-error session))))
      (etaf-salvage-test--act session "navigate" '(:x 12 :y 3))
      (should-not (etaf-gamekit-last-error session)))))

(ert-deftest etaf-salvage-expedition-can-complete-and-restart ()
  "Navigation, hazards, skills, objectives and restart form a playable loop."
  (etaf-salvage-test--with-game session
    (etaf-salvage-test--act session "navigate" '(:x 12 :y 3))
    (should (member '(9 4) (etaf-salvage-test--value session :world :route)))
    (etaf-salvage-test--act session "pause")
    (etaf-salvage-test--wait session (lambda () (= 1 (etaf-salvage-test--value session :pilot :cores))))
    (etaf-salvage-test--act session "pulse")
    (should-not (etaf-gamekit-last-error session))
    (should (< (etaf-salvage-test--value session :mission :drones) 3))
    (etaf-salvage-test--act session "pulse")
    (should (etaf-gamekit-last-error session))
    (etaf-salvage-test--act session "shield")
    (dolist (target '((2 26 4) (3 26 14)))
      (etaf-salvage-test--act session "navigate" (list :x (nth 1 target) :y (nth 2 target)))
      (etaf-salvage-test--wait session (lambda () (>= (etaf-salvage-test--value session :pilot :cores) (car target)))))
    (etaf-salvage-test--act session "navigate" '(:x 3 :y 14))
    (etaf-salvage-test--wait session (lambda () (eq t (etaf-salvage-test--value session :mission :won))))
    (let ((won (etaf-gamekit-observation session)))
      (should (>= (etaf-salvage-test--value session :pilot :score) 750))
      (should (equal won (etaf-salvage-test--act session "move" '(:x 1 :y 0))))
      (should (etaf-gamekit-last-error session)))
    (etaf-salvage-test--act session "restart")
    (should (= 0 (etaf-salvage-test--value session :pilot :cores)))
    (should (eq t (etaf-salvage-test--value session :mission :paused)))))

(ert-deftest etaf-salvage-damage-repair-and-defeat-stay-authoritative ()
  "Repair consumes a kit and an unprotected expedition can lose without UI rules."
  (etaf-salvage-test--with-game session
    (etaf-salvage-test--act session "navigate" '(:x 12 :y 3))
    (etaf-salvage-test--act session "pause")
    (etaf-salvage-test--wait session (lambda () (<= (etaf-salvage-test--value session :pilot :health) 88)))
    (etaf-salvage-test--act session "pause")
    (let ((health (etaf-salvage-test--value session :pilot :health)))
      (etaf-salvage-test--act session "repair")
      (should (= (etaf-salvage-test--value session :pilot :health) (min 100 (+ health 40))))
      (should (= (etaf-salvage-test--value session :pilot :repairs) 1)))
    (etaf-salvage-test--act session "pause")
    (etaf-salvage-test--wait session (lambda () (eq t (etaf-salvage-test--value session :mission :lost))) 15)
    (let ((lost (etaf-gamekit-observation session)))
      (should (= 0 (etaf-salvage-test--value session :pilot :health)))
      (should (equal lost (etaf-salvage-test--act session "move" '(:x 1 :y 0)))))))

(ert-deftest etaf-salvage-snapshot-recovery-is-atomic ()
  "Snapshots restore progress and malformed candidates preserve the live world."
  (etaf-salvage-test--with-game session
    (let ((file (make-temp-file "salvage-snapshot-")))
      (unwind-protect
          (progn
            (etaf-salvage-test--act session "navigate" '(:x 12 :y 3))
            (etaf-salvage-test--act session "pause")
            (etaf-salvage-test--wait session (lambda () (= 1 (etaf-salvage-test--value session :pilot :cores))))
            (let ((before (etaf-salvage-test--act session "pause")))
              (etaf-salvage-test--act session "save" (list :path file))
              (etaf-salvage-test--act session "restart")
              (let ((restored (etaf-salvage-test--act session "load" (list :path file))))
                (should (equal (plist-get before :pilot) (plist-get restored :pilot)))
                (should (equal (etaf-salvage-test--pilot before) (etaf-salvage-test--pilot restored)))
                (should (eq t (etaf-salvage-test--value session :mission :paused)))
                (dolist (invalid '("{broken" "{}" "[]"))
                  (with-temp-file file (insert invalid))
                  (let ((after (etaf-salvage-test--act session "load" (list :path file))))
                    (should (equal restored after))
                    (should (etaf-gamekit-last-error session)))))))
        (delete-file file)))))

(ert-deftest etaf-salvage-expeditions-are-independent ()
  "Operating one expedition cannot advance a second paused game."
  (etaf-salvage-test--with-game first
    (etaf-salvage-test--with-game second
      (let ((before (etaf-gamekit-observation second)))
        (etaf-salvage-test--act first "navigate" '(:x 7 :y 4))
        (etaf-salvage-test--act first "pause")
        (etaf-salvage-test--wait first (lambda () (= 7 (plist-get (etaf-salvage-test--pilot (etaf-gamekit-observation first)) :x))))
        (should (equal before (etaf-gamekit-observation second)))))))

(defun etaf-salvage-test--keys (session keys)
  "Send native KEYS to SESSION's displayed buffer."
  (with-current-buffer (etaf-gamekit-buffer session)
    (execute-kbd-macro (kbd keys))))

(defun etaf-salvage-test--help-visible-p (runtime)
  "Whether RUNTIME exposes the shared help's close control."
  (cl-some (lambda (entry)
             (equal (plist-get (cdr entry) :aria-label) "关闭帮助"))
           (etaf-runtime-host-props-entries runtime)))

(ert-deftest etaf-salvage-help-entries-share-read-only-modal ()
  "F1, Help and question mark share searchable help without changing the run."
  (save-window-excursion
    (etaf-salvage-test--with-game session
      (let* ((buffer (etaf-gamekit-buffer session))
             (runtime (etaf-runtime-for-buffer buffer)))
        (switch-to-buffer buffer)
        (etaf-refit runtime (selected-window))
        (etaf-salvage-test--wait
         session (lambda () (etaf-host-ref-size runtime 'salvage-map)))
        (dolist (entry '("<f1>" button "?"))
          (etaf-focus runtime 'salvage-help)
          (let ((focus (etaf-focused-host-ref runtime))
                (windows (window-list)) (buffers (buffer-list))
                (before (etaf-gamekit-observation session)))
            (if (eq entry 'button) (etaf-activate runtime)
              (etaf-salvage-test--keys session entry))
            (let* ((visible (etaf-salvage-test--help-visible-p runtime))
                   (data (etaf-help-data runtime))
                   (title (plist-get data :title))
                   (notes (string-join (plist-get data :notes) " "))
                   (bindings (apply #'append
                                    (mapcar (lambda (group) (plist-get group :entries))
                                            (plist-get data :groups))))
                   (move (cl-find "d" bindings :key (lambda (item) (plist-get item :key))
                                  :test #'equal)))
              (should visible)
              (should (equal title "Salvage Station"))
              (should (string-match-p "Recover.*cores" notes))
              (should (equal (plist-get move :label) "Move east"))
              (etaf-salvage-test--keys session "? d p 1 2 C-v")
              (let ((snapshot (etaf-help-data runtime)))
                (should (equal data snapshot))))
            (should (equal windows (window-list)))
            (should (equal buffers (buffer-list)))
            (should (eq buffer (window-buffer)))
            (etaf-salvage-test--keys session "/ d ? <escape>")
            (let ((visible (etaf-salvage-test--help-visible-p runtime))
                  (editing (not (null (etaf-text-input-active-p runtime)))))
              (should visible)
              (should-not editing))
            (etaf-salvage-test--keys session "<escape>")
            (etaf-salvage-test--wait session)
            (let ((after (etaf-gamekit-observation session))
                  (restored (etaf-focused-host-ref runtime))
                  (closed-again (etaf-help-close runtime)))
              (should (equal before after))
              (should (equal focus restored))
              (should-not closed-again))))))))

(ert-deftest etaf-salvage-help-preserves-live-simulation ()
  "Help keeps its scope and focus through live frames without changing pause policy."
  (save-window-excursion
    (etaf-salvage-test--with-game session
      (let* ((buffer (etaf-gamekit-buffer session))
             (runtime (etaf-runtime-for-buffer buffer)))
        (switch-to-buffer buffer)
        (etaf-refit runtime (selected-window))
        (etaf-salvage-test--wait
         session (lambda () (etaf-host-ref-size runtime 'salvage-map)))
        (etaf-focus runtime 'salvage-help)
        (etaf-salvage-test--act session "pause")
        (etaf-salvage-test--wait
         session (lambda () (not (eq t (plist-get (etaf-gamekit-view session :mission) :paused)))))
        (etaf-salvage-test--keys session "<f1>")
        (let ((focus (etaf-focused-host-ref runtime))
              (snapshot (etaf-help-data runtime))
              (seconds (etaf-salvage-test--value session :mission :seconds)))
          (etaf-salvage-test--wait
           session (lambda () (> (plist-get (etaf-gamekit-view session :mission) :seconds)
                                  seconds)))
          (let ((visible (etaf-salvage-test--help-visible-p runtime))
                (after-focus (etaf-focused-host-ref runtime))
                (after-data (etaf-help-data runtime))
                (paused (etaf-salvage-test--value session :mission :paused)))
            (should visible)
            (should (equal focus after-focus))
            (should (equal snapshot after-data))
            (should-not (eq t paused)))
          (etaf-salvage-test--keys session "<escape>")
          (let ((restored (etaf-focused-host-ref runtime))
                (paused (etaf-salvage-test--value session :mission :paused)))
            (should (eq restored 'salvage-help))
            (should-not (eq t paused))))))))

(provide 'etaf-salvage-tests)
;;; etaf-salvage-tests.el ends here
