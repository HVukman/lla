;;; -*- Mode:Lisp; Syntax:ANSI-Common-Lisp; Coding:utf-8 -*-

(in-package #:lla)

;;; SUB and (SETF SUB)
;;;
;;; We traverse the matrix as if it was transposed and row-major,
;;; using the WITH-INDEXING macro.  (SETF SUB) will silently set
;;; restricted elements, without raising an error.

(defmethod sub ((matrix dense-matrix-like) &rest ranges)
  (bind (((row-range col-range) ranges)
         ((:slots-r/o elements nrow ncol) matrix))
    (with-indexing ((list col-range row-range)
                          (vector ncol nrow)
                          matrix-index
                          :effective-dimensions result-dimensions)
      (bind (((:values result-length result-elements
                       result)
              (ecase (length result-dimensions)
                (0 (return-from sub (aref elements (matrix-index))))
                (1 (bind ((#(length) result-dimensions)
                          (result (make-similar-vector elements
                                                       length)))
                     (values length result result)))
                (2 (bind ((#(result-ncol result-nrow)
                           result-dimensions)
                          (result-length (* result-ncol result-nrow))
                          (result-elements (make-similar-vector
                                            elements
                                            result-length)))
                     (values result-length
                             result-elements
                             (make-matrix% result-nrow result-ncol
                                           result-elements
                                          :kind 
                                          (matrix-kind matrix))))))))
        (with-vector-type-declarations (elements
                                        :other-vectors
                                        (result-elements))
          (iter
            (for result-index :from 0 :below result-length)
            (setf (aref result-elements result-index)
                  (aref elements (matrix-index)))))
        result))))

;;; (setf sub)

(defmethod (setf sub) ((source number)
                       (destination dense-matrix-like) &rest ranges)
  (bind (((row-range col-range) ranges)
         ((:slots-r/o (destination-elements elements) nrow ncol)
          destination))
    (with-indexing ((list col-range row-range) ; flip order
                          (vector ncol nrow)
                          matrix-index
                          :effective-dimensions
                          destination-dimensions
                          :end? end?)
      (iter
        (setf (aref destination-elements (matrix-index))
              source)
        (until end?))))
  source)

(defmethod (setf sub) ((source vector)
                       (destination dense-matrix-like) &rest ranges)
  (bind (((row-range col-range) ranges)
         ((:slots-r/o (destination-elements elements) nrow ncol)
          destination))
    (with-indexing ((list col-range row-range)
                          (vector ncol nrow)
                          matrix-index
                          :effective-dimensions
                          destination-dimensions)
      (bind ((#(length) destination-dimensions))
        (assert (= length (length source)) ()
                'sub-incompatible-dimensions)
        (iter
          (for source-index :from 0 :below length)
          (setf (aref destination-elements (matrix-index))
                (aref source source-index))))))
  source)

(defmethod (setf sub) ((source dense-matrix-like)
                       (destination dense-matrix-like) &rest ranges)
  ;; we traverse both matrices as if they were transposed and
  ;; row-major.  Restricted elements are set, but this raises no error
  ;; message - my guess is that skipping them based on type would be
  ;; more costly.
  (bind (((row-range col-range) ranges)
         ((:slots-r/o (destination-elements elements) nrow ncol)
          destination))
    (with-indexing ((list col-range row-range)
                          (vector ncol nrow)
                          matrix-index
                          :effective-dimensions
                          destination-dimensions)
      (bind ((source-elements (elements source))
             (#(ncol nrow) destination-dimensions))
        (assert (and (= (nrow source) nrow)
                     (= (ncol source) ncol)) ()
                     'sub-incompatible-dimensions)
        (set-restricted source)
        (iter
          (for source-index :from 0 :below (* nrow ncol))
          (setf (aref destination-elements (matrix-index))
                (aref source-elements source-index))))))
  source)

(defmethod (setf sub) ((source array)
                       (destination dense-matrix-like) &rest ranges)
  (bind (((row-range col-range) ranges)
         ((:slots-r/o (destination-elements elements) nrow ncol)
          destination))
    (with-indexing ((list col-range row-range)
                          (vector ncol nrow)
                          matrix-index
                          :end? end?
                          :effective-dimensions
                          destination-dimensions
                          :counters destination-counters)
      (bind ((#(ncol nrow) destination-dimensions)
             ((source-nrow source-ncol) (array-dimensions source)))
        (assert (and (= source-nrow nrow)
                     (= source-ncol ncol)) ()
                     'sub-incompatible-dimensions)
        (iter
          (until end?)
          (bind ((#(col row) destination-counters))
            (setf (aref destination-elements (matrix-index))
                  (aref source row col)))))))
  source)
    
(defmethod create ((type (eql 'dense-matrix)) element-type &rest dimensions)
  (bind (((nrow ncol) dimensions))
    (make-matrix nrow ncol (representable-lla-type element-type))))

(defmethod pref ((matrix dense-matrix-like) &rest indexes)
  (bind (((row-indexes col-indexes) indexes)
         ((:slots-r/o nrow ncol elements) matrix)
         (length (length row-indexes))
         (result (make-array length :element-type (array-element-type elements))))
    (assert (= length (length col-indexes)))
    (set-restricted matrix)
    (dotimes (element-index length)
      (setf (aref result element-index)
            (let ((row (aref row-indexes element-index))
                  (col (aref col-indexes element-index)))
              (assert (and (within? 0 row nrow) (within? 0 col ncol)))
              (aref elements (cm-index2 nrow row col)))))
    result))
