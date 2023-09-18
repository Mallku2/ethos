(declare-sort Int 0)
(declare-consts <numeral> Int)

(declare-const = (-> (! Type :var T :implicit) T T Bool))
(declare-const + (-> Int Int Int))
(declare-const - (-> Int Int Int))

(program arith.eval ((S Type) (a Int) (b Int) (z S))
    (S) S
    (
      ((arith.eval (= a b))  (alf.is_eq (arith.eval a) (arith.eval b)))
      ((arith.eval (+ a b))  (alf.add (arith.eval a) (arith.eval b)))
      ((arith.eval (- a b))  (alf.add (arith.eval a) (alf.neg (arith.eval b))))
      ((arith.eval z)        z)
    )
)

(declare-sort String 0)
(declare-consts <string> String)
  
(declare-const str.++ (-> String String String))
(declare-const str.len (-> String Int))
(declare-const str.substr (-> String Int Int String))
(declare-const str.indexof (-> String String Int Int))

(program str.eval ((S Type) (a String) (b String) (z S) (n Int) (m Int))
    (S) S
    (
      ((str.eval (= a b))            (alf.is_eq (str.eval a) (str.eval b)))
      ((str.eval (str.++ a b))       (alf.concat (str.eval a) (str.eval b)))
      ((str.eval (str.len a))        (alf.len (str.eval a)))
      ((str.eval (str.substr a n m)) (let ((en (str.eval n)))
                                        (alf.extract (str.eval a) en (alf.add en (str.eval m)))))
      ((str.eval (str.indexof a b n))(let ((en (str.eval n)))
                                     (let ((ea (str.eval a)))
                                     (let ((eas (str.eval (str.substr ea en (str.len ea)))))
                                     (let ((et (alf.find eas b)))
                                       (alf.ite (alf.is_neg et) et (alf.add en et)))))))
      ((str.eval z)                  (arith.eval z))
    )
)

(declare-rule eval
   ((T Type) (U Type) (a T) (b U))
   :premises ()
   :args (a b)
   :requires (((str.eval a) (str.eval b)))
   :conclusion (= a b)
)

(declare-const x String)

(step a2 (= 4 (str.len "ABCD")) :rule eval :premises (4 (str.len "ABCD")))
(step a3 (= 1 (str.len "\u{45}")) :rule eval :premises (1 (str.len "\u{45}")))
(step a4 (= "B" (str.substr (str.++ "A" "BC") 1 1)) :rule eval :premises ("B" (str.substr (str.++ "A" "BC") 1 1)))
(step a5 (= 9 (str.len "\u{45}\uu{\u1A11\u0")) :rule eval :premises (9 (str.len "\u{45}\uu{\u1A11\u0")))
(step a6 (= "E" "\u{45}") :rule eval :premises ("E" "\u{45}"))
(step a7 (= (str.indexof "AAB" "B" 0) 2) :rule eval :premises ((str.indexof "AAB" "B" 0) 2))
(step a8 (= (str.indexof "ABB" "A" 2) (alf.neg 1)) :rule eval :premises ((str.indexof "ABB" "A" 2) (alf.neg 1)))
