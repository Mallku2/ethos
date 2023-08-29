(include "../proofs/theories/Core.smt2")
(include "../proofs/programs/Nary.smt2")

; NOT_AND
(program lowerNot ((l Bool) (ls Bool :list))
    (Bool) Bool
    (
        ((lowerNot (alf.nil Bool)) (alf.nil Bool))
        ((lowerNot (and l ls)) (nary.append or (not l) (lowerNot ls)))
    )
)

(declare-rule not_and ((F Bool))
    :premises ((not F))
    :conclusion (lowerNot F)
)

; not_and
(declare-const c1 Bool)
(declare-const c2 Bool)
(assume notanda1 (not (and c1 c2 (not c2))))
(step   notandt1 (or (not c1) (not c2) (not (not c2))) :rule not_and :premises (notanda1))
