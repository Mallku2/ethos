(include "./substitution-over-or.smt2")

(declare-const a Bool)
(declare-const b Bool)
(declare-const c Bool)
(assume a1 (or a (and a b c a b c) c a (and (not c) b) (and (not a) a) b))
(assume a2 (= a b))
(step a3 (or b (and a b c a b c) c b (and (not c) b) (and (not a) a) b) :rule eq-subs-over-or :premises (a1 a2))
