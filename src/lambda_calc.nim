
import std/cmdline
#import sequtils

proc map[T, S](s: openArray[T], op: proc (x: T): S {.closure.}): seq[S] {.inline, effectsOf: op.} =
    newSeq(result, s.len)
    for i in 0 ..< s.len:
        result[i] = op(s[i])

func foldr[T, S](s: seq[T], op: proc (x: T, y: S): S {.closure.}, z: S, idx = 0): S {.inline, effectsOf: op.} =
    if idx>=s.len: return z
    result = s[idx]
    for i in 0 ..< s.len:
        result = op(result, foldr(s, op, z, idx+1))
    
func hasPrefix(s1, s2: string): bool =
    if s2.len > s1.len: return false
    for i in 0..<s2.len:
        if s1[i] != s2[i]: return false
    return true


type
    TokenKind = enum
        paren, symbol, define, lambda, dot, newline, pair_paren,
        church_paren, scott_paren, character, str, boolean,
        number, delimiter, quote, eof
    Token = object
        case kind: TokenKind
            of paren:
                open: bool
            of symbol:
                symbol: string
            of define:
                discard
            of lambda:
                discard
            of dot:
                discard
            of newline:
                discard
            of pair_paren:
                pair_open: bool
            of church_paren:
                church_open: bool
            of scott_paren:
                scott_open: bool
            of character:
                character: char
            of str:
                str: string
            of boolean:
                boolean: bool
            of number:
                number: int
            of delimiter:
                discard
            of quote:
                discard
            of eof:
                discard
    SymbolKind = enum
        pure, iofunc, io_int, io_pair, io_bool, io_church_list,
        io_scott_list, io_char, io_string
    Symbol = object
        instance: int = 0
        case kind: SymbolKind
            of pure:
                symbol: string
            of iofunc:
                iofunc: int
            of io_int:
                io_int: int64
            of io_pair:
                io_pair: (Term, Term)
            of io_bool:
                io_bool: bool
            of io_church_list:
                io_church_list: seq[Term]
            of io_scott_list:
                io_scott_list: seq[Term]
            of io_char:
                io_char: char
            of io_string:
                io_string: string
    Atom = object
        case kind: uint8
            of 0:
                symbol: Symbol
            of 1:
                term: Term
            of 2:
                abstraction: Abstraction
            else:
                discard
    Application = ref object
        case is_atom: bool
            of true:
                value: Atom
            of false:
                application: Application
                atom: Atom
    Abstraction = object
        input: Symbol
        output: Term
    Term = ref object
        case is_application: bool
            of true:
                application: Application
            of false:
                abstraction: Abstraction
    Definition = object
        symbol: Symbol
        term: Term
    Statement = object
        case is_term: bool
            of true:
                term: Term
            of false:
                definition: Definition

proc `==`(a, b: Token): bool =
    if a.kind != b.kind:
        return false
    case a.kind:
        of paren:
            return a.open == b.open
        of symbol:
            return a.symbol == b.symbol
        else:
            return true

proc `==`(a, b: Symbol): bool =
    if a.kind != b.kind or a.instance != b.instance:
        return false
    case a.kind:
        of pure:
            return a.symbol == b.symbol
        of iofunc:
            return a.iofunc == b.iofunc
        of io_int:
            return a.io_int == b.io_int
        of io_pair:
            return a.io_pair == b.io_pair
        of io_bool:
            return a.io_bool == b.io_bool
        of io_church_list:
            return a.io_church_list == b.io_church_list
        of io_scott_list:
            return a.io_scott_list == b.io_scott_list
        of io_char:
            return a.io_char == b.io_char
        of io_string:
            return a.io_string == b.io_string

func `==`(a, b: Term): bool
func `==`(a, b: Abstraction): bool

type
    ASTNodeKind = enum
        atom_k, application_k, abstraction_k, term_k
    ASTNode = object
        case kind: ASTNodeKind
            of atom_k:
                atom: Atom
            of application_k:
                application: Application
            of abstraction_k:
                abstraction: Abstraction
            of term_k:
                term: Term
    ASTNodeEqOutput = object
        case result: bool
            of true:
                is_equal: bool
            of false:
                pairs: seq[(ASTNode, ASTNode)]

func astNodeEq(a, b: ASTNode): ASTNodeEqOutput =
    if a.kind != b.kind:
        return ASTNodeEqOutput(result: true, is_equal: false)
    case a.kind:
        of atom_k:
            var
                rhs = b.atom
                lhs = a.atom
            if lhs.kind != rhs.kind:
                return ASTNodeEqOutput(result: true, is_equal: false)
            case lhs.kind:
                of 0: return ASTNodeEqOutput(result: true, is_equal: lhs.symbol == rhs.symbol)
                of 1: return ASTNodeEqOutput(result: false, pairs: @[(ASTNode(kind: term_k, term: lhs.term), ASTNode(kind: term_k, term: rhs.term))])
                of 2: return ASTNodeEqOutput(result: false, pairs: @[(ASTNode(kind: abstraction_k, abstraction: lhs.abstraction), ASTNode(kind: abstraction_k, abstraction: rhs.abstraction))])
                else: assert(false, "malformed atom")
        of application_k:
            var
                lhs = a.application
                rhs = b.application
            if lhs.is_atom != rhs.is_atom:
                return ASTNodeEqOutput(result: true, is_equal: false)
            if lhs.is_atom:
                return ASTNodeEqOutput(result: false, pairs: @[(ASTNode(kind: atom_k, atom: lhs.value), ASTNode(kind: atom_k, atom: rhs.value))])
            else:
                return ASTNodeEqOutput(result: false, pairs: @[(ASTNode(kind: application_k, application: lhs.application), ASTNode(kind: application_k, application: rhs.application)), (ASTNode(kind: atom_k, atom: lhs.atom), ASTNode(kind: atom_k, atom: rhs.atom))])
        of abstraction_k:
            var
                lhs = a.abstraction
                rhs = b.abstraction
            if lhs.input != rhs.input: return ASTNodeEqOutput(result: true, is_equal: false)
            return ASTNodeEqOutput(result: false, pairs: @[(ASTNode(kind: term_k, term: lhs.output), ASTNode(kind: term_k, term: rhs.output))])
        of term_k:
            var
                lhs = a.term
                rhs = b.term
            if lhs.is_application != rhs.is_application:
                return ASTNodeEqOutput(result: true, is_equal: false)
            if lhs.is_application:
                return ASTNodeEqOutput(result: false, pairs: @[(ASTNode(kind: application_k, application: lhs.application), ASTNode(kind: application_k, application: rhs.application))])
            else:
                return ASTNodeEqOutput(result: false, pairs: @[(ASTNode(kind: abstraction_k, abstraction: lhs.abstraction), ASTNode(kind: abstraction_k, abstraction: rhs.abstraction))])

func `==`(a, b: Atom): bool =
    var
        lhs = ASTNode(kind: atom_k, atom: a)
        rhs = ASTNode(kind: atom_k, atom: b)
        pairs: seq[(ASTNode, ASTNode)] = @[(lhs, rhs)]
    while pairs.len > 0:
        let
            pair = pairs[pairs.high]
            res = astNodeEq(pair[0], pair[1])
        pairs.delete(pairs.high)
        if res.result == true:
            if res.is_equal == false: return false
        else:
            for i in res.pairs:
                pairs.add(i)
    return true

func `==`(a, b: Application): bool =
    var
        lhs = ASTNode(kind: application_k, application: a)
        rhs = ASTNode(kind: application_k, application: b)
        pairs: seq[(ASTNode, ASTNode)] = @[(lhs, rhs)]
    while pairs.len > 0:
        let
            pair = pairs[pairs.high]
            res = astNodeEq(pair[0], pair[1])
        pairs.delete(pairs.high)
        if res.result == true:
            if res.is_equal == false: return false
        else:
            for i in res.pairs:
                pairs.add(i)
    return true

func `==`(a, b: Abstraction): bool =
    var
        lhs = ASTNode(kind: abstraction_k, abstraction: a)
        rhs = ASTNode(kind: abstraction_k, abstraction: b)
        pairs: seq[(ASTNode, ASTNode)] = @[(lhs, rhs)]
    while pairs.len > 0:
        let
            pair = pairs[pairs.high]
            res = astNodeEq(pair[0], pair[1])
        pairs.delete(pairs.high)
        if res.result == true:
            if res.is_equal == false: return false
        else:
            for i in res.pairs:
                pairs.add(i)
    return true

func `==`(a, b: Term): bool =
    var
        lhs = ASTNode(kind: term_k, term: a)
        rhs = ASTNode(kind: term_k, term: b)
        pairs: seq[(ASTNode, ASTNode)] = @[(lhs, rhs)]
    while pairs.len > 0:
        let
            pair = pairs[pairs.high]
            res = astNodeEq(pair[0], pair[1])
        pairs.delete(pairs.high)
        if res.result == true:
            if res.is_equal == false: return false
        else:
            for i in res.pairs:
                pairs.add(i)
    return true

func reduce(term: Term): Term
func pretty(term: Term): string
func BV(M: Term): seq[Symbol]
func FV(M: Term): seq[Symbol]
func union[T](a, b: seq[T]): seq[T]

func io_int_to_church(value: Atom, final_parent: Term): Term =
    if value.kind != 0 or value.symbol.kind != io_int or value.symbol.io_int < 0:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    let integer = value.symbol.io_int
    var intermediate = Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "z")))
    for i in 0..<integer:
        intermediate = Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "s"))), atom: Atom(kind: 1, term: Term(is_application: true, application: intermediate)))
    return Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "s"), output: Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "z"), output: Term(is_application: true, application: intermediate)))))

func io_church_to_int(value: Atom, final_parent: Term): Term =
    let body = reduce(Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: false, application: Application(is_atom: true, value: value), atom: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "+"))), atom: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "0")))))
    if not body.is_application:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    var
        application = body.application
        integer = 0'i64
    while not application.is_atom and application.application.is_atom and application.application.value.kind == 0 and application.application.value.symbol.kind == pure and application.application.value.symbol.symbol == "+":
        integer += 1
        if 
            (application.atom.kind != 1 or not application.atom.term.is_application) and
            (application.atom.kind != 0 or application.atom.symbol != Symbol(kind: pure, symbol: "0")):
                return Term(is_application: true, application: Application(is_atom: true, value: application.atom))
        if application.atom.kind == 1:
            application = application.atom.term.application
        else:
            break
    if application == Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "0"))):
        return Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: io_int, io_int: integer))))
    elif application == Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "+"))), atom: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "0"))):
        return Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: io_int, io_int: integer))))
    return Term(is_application: true, application: Application(is_atom: true, value: value))

func io_church_to_pair(value: Atom, final_parent: Term): Term =
    let
        t = Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "x"), output: Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "y"), output: Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "x"))))))))
        f = Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "x"), output: Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "y"), output: Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "y"))))))))
        lhs = reduce(Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: value), atom: Atom(kind: 1, term: t))))
        rhs = reduce(Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: value), atom: Atom(kind: 1, term: f))))
    return Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: io_pair, io_pair: (lhs, rhs)))))

func io_pair_to_church(value: Atom, final_parent: Term): Term =
    if value.kind != 0 or value.symbol.kind != io_pair:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    
    let free_vars = FV(value.symbol.io_pair[0]).union(FV(value.symbol.io_pair[1]))
    var symbol_b = Symbol(kind: pure, symbol: "b")
    while free_vars.contains(symbol_b):
        symbol_b.instance += 1
    
    return Term(
        is_application: false,
        abstraction: Abstraction(
            input: symbol_b,
            output: Term(
                is_application: true,
                application: Application(
                    is_atom: false,
                    application: Application(
                        is_atom: false,
                        application: Application(
                            is_atom: true,
                            value: Atom(
                                kind: 0,
                                symbol: symbol_b
                            )),
                        atom: Atom(
                            kind: 1,
                            term: value.symbol.io_pair[0]
                        )
                    ),
                    atom: Atom(
                        kind: 1,
                        term: value.symbol.io_pair[1]
                    )
                )
            )
        )
    )

func io_church_to_bool(value: Atom, final_parent: Term): Term =
    return reduce(
        Term(
            is_application: true,
            application: Application(
                is_atom: false,
                application: Application(
                    is_atom: false,
                    application: Application(
                        is_atom: true,
                        value: value
                    ),
                    atom: Atom(kind: 0, symbol: Symbol(kind: io_bool, io_bool: true))
                ),
                atom: Atom(kind: 0, symbol: Symbol(kind: io_bool, io_bool: false))
            )
        )
    )

func io_bool_to_church(value: Atom, final_parent: Term): Term =
    if value.kind != 0 or value.symbol.kind != io_bool:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    let bool_value = value.symbol.io_bool
    if bool_value:
        return Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "x"), output: Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "y"), output: Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "x"))))))))
    else:
        return Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "x"), output: Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "y"), output: Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "y"))))))))

func io_church_to_list(value: Atom, final_parent: Term): Term =
    if value.kind != 2:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    #apply value's application to the symbols cons and nil then pattern match agains: cons a (cons b (cons c ... nil))
    let body = reduce(
        Term(
            is_application: true,
            application: Application(
                is_atom: false,
                application: Application(
                    is_atom: false,
                    application: Application(
                        is_atom: true,
                        value: value
                    ),
                    atom: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "cons"))
                ),
                atom: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "nil"))
            )
        )
    )
    if not body.is_application:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    var
        application = body.application
        list: seq[Term] = @[]

    while not application.is_atom and not application.application.is_atom and application.application.application.is_atom and application.application.application.value == Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "cons")):
        let elem: Atom = application.application.atom
        case elem.kind:
            of 0:
                list.add(Term(is_application: true, application: Application(is_atom: true, value: elem)))
            of 1:
                list.add(elem.term)
            of 2:
                list.add(Term(is_application: false, abstraction: elem.abstraction))
            else:
                assert(false, "malformed atom")
        if
            (application.atom.kind != 1 or not application.atom.term.is_application) and
            (application.atom.kind != 0 or application.atom.symbol != Symbol(kind: pure, symbol: "nil")):
                return Term(is_application: true, application: Application(is_atom: true, value: value))
        if application.atom.kind == 1:
            application = application.atom.term.application
        else:
            application = Application(is_atom: true, value: application.atom)
    if application == Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "nil"))):
        return Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: io_church_list, io_church_list: list))))
    else:
        return Term(is_application: true, application: Application(is_atom: true, value: value))

func io_list_to_church(value: Atom, final_parent: Term): Term =
    if value.kind != 0 or value.symbol.kind != io_church_list:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    var
        symbol_nil = Symbol(kind: pure, symbol: "nil")
        symbol_cons = Symbol(kind: pure, symbol: "cons")
        list = value.symbol.io_church_list
    let
        free_vars = value.symbol.io_church_list.map(FV).foldr(union, newSeq[Symbol](0))
    while free_vars.contains(symbol_nil):
        symbol_nil.instance += 1
    while free_vars.contains(symbol_cons):
        symbol_cons.instance += 1
    var application = Application(is_atom: true, value: Atom(kind: 0, symbol: symbol_nil))
    while list.len > 0:
        application = Application(
            is_atom: false,
            application: Application(
                is_atom: false,
                application: Application(
                    is_atom: true,
                    value: Atom(kind: 0,
                        symbol: symbol_cons
                    )
                ),
                atom: Atom(
                    kind: 1,
                    term: list[list.high]
                )
            ),
            atom: Atom(
                kind: 1,
                term: Term(
                    is_application: true,
                    application: application
                )
            )
        )
        list.del(list.high)
    return Term(
        is_application: false,
        abstraction: Abstraction(
            input: symbol_cons,
            output: Term(
                is_application: false,
                abstraction: Abstraction(
                    input: symbol_nil,
                    output: Term(
                        is_application: true,
                        application: application
                    )
                )
            )
        )
    )

func io_scott_to_list(value: Atom, final_parent: Term): Term =
    let term = reduce(Term(is_application: true, application: Application(is_atom: true, value: value)))
    if term.is_application or term.abstraction.output.is_application or not term.abstraction.output.abstraction.output.is_application:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    var
        cons_atom = Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "cons"))
        nil_atom = Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "nil"))
    while cons_atom.symbol in FV(term) or cons_atom.symbol in BV(final_parent):
        cons_atom.symbol.instance += 1
    while nil_atom.symbol in FV(term) or nil_atom.symbol in BV(final_parent):
        nil_atom.symbol.instance += 1
    var
        inter = reduce(Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 2, abstraction: term.abstraction)), atom: cons_atom), atom: nil_atom)))
        list: seq[Term] = @[]
    while inter != Term(is_application: true, application: Application(is_atom: true, value: nil_atom)):
        if
            not inter.is_application or
            inter.application.is_atom or
            inter.application.application.is_atom or
            not inter.application.application.application.is_atom or
            inter.application.application.application.value != cons_atom:
                #assert(false, pretty(inter))
                return Term(is_application: true, application: Application(is_atom: true, value: value))
        #inter is cons_atom head tail
        list.add(Term(is_application: true, application: Application(is_atom: true, value: inter.application.application.atom)))
        inter = reduce(Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: false, application: Application(is_atom: true, value: inter.application.atom), atom: cons_atom), atom: nil_atom)))
    return Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: io_scott_list, io_scott_list: list))))

func io_list_to_scott(value: Atom, final_parent: Term): Term =
    if value.kind != 0 or value.symbol.kind != io_scott_list:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    var
        list = value.symbol.io_scott_list
        cons_atom = Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "cons"))
        nil_atom = Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "nil"))
        output_atom = Atom(kind: 2, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "x"), output: Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "y"), output: Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "y"))))))))
    let
        free_vars = value.symbol.io_scott_list.map(FV).foldr(union, newSeq[Symbol](0))
    while free_vars.contains(cons_atom.symbol):
        cons_atom.symbol.instance += 1
    while free_vars.contains(nil_atom.symbol):
        nil_atom.symbol.instance += 1
    while list.len > 0:
        output_atom = Atom(kind: 2, abstraction: Abstraction(input: cons_atom.symbol, output: Term(is_application: false, abstraction: Abstraction(input: nil_atom.symbol, output: Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: false, application: Application(is_atom: true, value: cons_atom), atom: Atom(kind: 1, term: list[list.high])), atom: output_atom))))))
        list.delete(list.high)
    return Term(is_application: true, application: Application(is_atom: true, value: output_atom))

func io_church_to_char(value: Atom, final_parent: Term): Term =
    let body = reduce(Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: false, application: Application(is_atom: true, value: value), atom: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "+"))), atom: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "0")))))
    if not body.is_application:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    var
        application = body.application
        integer = 0'u8
    while not application.is_atom and application.application.is_atom and application.application.value.kind == 0 and application.application.value.symbol.kind == pure and application.application.value.symbol.symbol == "+":
        integer += 1
        if 
            (application.atom.kind != 1 or not application.atom.term.is_application) and
            (application.atom.kind != 0 or application.atom.symbol != Symbol(kind: pure, symbol: "0")):
                return Term(is_application: true, application: Application(is_atom: true, value: application.atom))
        if application.atom.kind == 1:
            application = application.atom.term.application
        else:
            break
    if application == Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "0"))):
        return Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: io_char, io_char: cast[char](integer)))))
    elif application == Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "+"))), atom: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "0"))):
        return Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: io_char, io_char: cast[char](integer)))))
    return Term(is_application: true, application: Application(is_atom: true, value: value))

func io_char_to_church(value: Atom, final_parent: Term): Term =
    if value.kind != 0 or value.symbol.kind != io_char:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    let integer = int(cast[uint8](value.symbol.io_char))
    var intermediate = Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "z")))
    for i in 0..<integer:
        intermediate = Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "s"))), atom: Atom(kind: 1, term: Term(is_application: true, application: intermediate)))
    return Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "s"), output: Term(is_application: false, abstraction: Abstraction(input: Symbol(kind: pure, symbol: "z"), output: Term(is_application: true, application: intermediate)))))

func io_scott_to_string(value: Atom, final_parent: Term): Term =
    let term = reduce(Term(is_application: true, application: Application(is_atom: true, value: value)))
    if term.is_application or term.abstraction.output.is_application or not term.abstraction.output.abstraction.output.is_application:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    var
        cons_atom = Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "cons"))
        nil_atom = Atom(kind: 0, symbol: Symbol(kind: pure, symbol: "nil"))
    while cons_atom.symbol in FV(term) or cons_atom.symbol in BV(final_parent):
        cons_atom.symbol.instance += 1
    while nil_atom.symbol in FV(term) or nil_atom.symbol in BV(final_parent):
        nil_atom.symbol.instance += 1
    var
        inter = reduce(Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 2, abstraction: term.abstraction)), atom: cons_atom), atom: nil_atom)))
        list: seq[Term] = @[]
    while inter != Term(is_application: true, application: Application(is_atom: true, value: nil_atom)):
        if
            not inter.is_application or
            inter.application.is_atom or
            inter.application.application.is_atom or
            not inter.application.application.application.is_atom or
            inter.application.application.application.value != cons_atom:
                #assert(false, pretty(inter))
                return Term(is_application: true, application: Application(is_atom: true, value: value))
        #inter is cons_atom head tail
        list.add(Term(is_application: true, application: Application(is_atom: true, value: inter.application.application.atom)))
        inter = reduce(Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: false, application: Application(is_atom: true, value: inter.application.atom), atom: cons_atom), atom: nil_atom)))
    func curried_to_char(value: Term): Term = io_church_to_char(Atom(kind: 1, term: value), final_parent)
    let str = list.map(curried_to_char)
    var output = ""
    for i in str:
        let item = reduce(i)
        if not item.is_application or not item.application.is_atom or item.application.value.kind != 0 or item.application.value.symbol.kind != io_char:
            return Term(is_application: true, application: Application(is_atom: true, value: value))
        output.add(item.application.value.symbol.io_char)
    return Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: io_string, io_string: output))))

func io_string_to_scott(value: Atom, final_parent: Term): Term =
    let term = reduce(Term(is_application: true, application: Application(is_atom: true, value: value)))
    if not term.is_application or not term.application.is_atom or term.application.value.kind != 0 or term.application.value.symbol.kind != io_string:
        return Term(is_application: true, application: Application(is_atom: true, value: value))
    let str = term.application.value.symbol.io_string
    var
        list: seq[char] = @[]
    for i in str:
        list.add(i)
    func char_to_char_term(input: char): Term =
        return Term(is_application: true, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: io_char, io_char: input))))
    return io_list_to_scott(Atom(kind: 0, symbol: Symbol(kind: io_scott_list, io_scott_list: list.map(char_to_char_term))), final_parent)

const
    alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    digits = "0123456789"
    iofuncs = [
        io_church_to_int,
        io_int_to_church,
        io_church_to_pair,
        io_pair_to_church,
        io_church_to_bool,
        io_bool_to_church,
        io_church_to_list,
        io_list_to_church,
        io_scott_to_list,
        io_list_to_scott,
        io_church_to_char,
        io_char_to_church,
        io_scott_to_string,
        io_string_to_scott,
        ]
    iofunc_names = [
        "io-church-to-int",
        "io-int-to-church",
        "io-church-to-pair",
        "io-pair-to-church",
        "io-church-to-bool",
        "io-bool-to-church",
        "io-church-to-list",
        "io-list-to-church",
        "io-scott-to-list",
        "io-list-to-scott",
        "io-church-to-char",
        "io-char-to-church",
        "io-scott-to-string",
        "io-string-to-scott",
        ]
    stdlibs = [
        staticRead("../stdlib/combinators.plm"),
        staticRead("../stdlib/birds.plm"),
        staticRead("../stdlib/combinator_names.plm"),
        staticRead("../stdlib/base.plm"),
        staticRead("../stdlib/maths.plm"),
        staticRead("../stdlib/compounds.plm"),
        staticRead("../stdlib/monads.plm")
    ]
    stdlib_names = [
        "std/combinators",
        "std/birds",
        "std/combinator-names",
        "std/base",
        "std/maths",
        "std/compounds",
        "std/monads"
    ]
var
    filesRead: seq[string]
    inputs: seq[string]

proc getInput(num: int, msg: string): string =
    while num >= inputs.len:
        write(stdout, msg)
        inputs.add(readLine(stdin))
    return inputs[num]

proc tokenise (input: string): seq[Token] =
    proc expand_includes(input: seq[Token]): seq[Token] =
        var output = input
        return output
    var
        output: seq[Token] = @[]
        idx: int = 0
        input_num: int = 0
    while idx < input.len:
        if input[idx] == '(':
            idx += 1
            output.add(Token(kind: paren, open: true))
        elif input[idx] == ')':
            idx += 1
            output.add(Token(kind: paren, open: false))
        elif input[idx] == '<':
            idx += 1
            output.add(Token(kind: pair_paren, pair_open: true))
        elif input[idx] == '>':
            idx += 1
            output.add(Token(kind: pair_paren, pair_open: false))
        elif input[idx] == '[':
            idx += 1
            output.add(Token(kind: church_paren, church_open: true))
        elif input[idx] == ']':
            idx += 1
            output.add(Token(kind: church_paren, church_open: false))
        elif input[idx] == '{':
            idx += 1
            output.add(Token(kind: scott_paren, scott_open: true))
        elif input[idx] == '}':
            idx += 1
            output.add(Token(kind: scott_paren, scott_open: false))
        elif input[idx] in alpha:
            var acc = ""
            while (idx < input.len) and ((input[idx] in alpha) or (input[idx] in digits) or (input[idx] == '-')):
                acc.add(input[idx])
                idx += 1
            if acc == "define" or acc == "define-unsafe":
                output.add(Token(kind: define))
            elif acc == "io-include":
                while input[idx] in [' ', '\t']:
                    idx += 1
                assert(input[idx] == '\"', "include must be followed by a filepath string")
                acc = ""
                idx += 1
                while input[idx] != '"':
                    acc.add(input[idx])
                    idx += 1
                idx += 1
                assert(not (acc in filesRead), "circular include")
                filesRead.add(acc)
                let input_file = if acc.hasPrefix("std/"): stdlibs[stdlib_names.find(acc)] else: readFile(acc & ".plm")
                for i in tokenise(input_file):
                    if i != Token(kind: eof): output.add(i)
            elif acc == "io-include-permissive":
                while input[idx] in [' ', '\t']:
                    idx += 1
                assert(input[idx] == '\"', "include must be followed by a filepath string")
                acc = ""
                idx += 1
                while input[idx] != '"':
                    acc.add(input[idx])
                    idx += 1
                idx += 1
                if not (acc in filesRead):
                    filesRead.add(acc)
                    let input_file = if acc.hasPrefix("std/"): stdlibs[stdlib_names.find(acc)] else: readFile(acc & ".plm")
                    for i in tokenise(input_file):
                        if i != Token(kind: eof): output.add(i)
            elif acc == "io-input":
                while input[idx] in [' ', '\t']:
                    idx += 1
                assert(input[idx] == '\"', "input must be followed by a message string")
                acc = ""
                idx += 1
                while input[idx] != '"':
                    acc.add(input[idx])
                    idx += 1
                idx += 1
                for i in tokenise(getInput(input_num, acc)):
                    output.add(i)
                input_num += 1
            else:
                output.add(Token(kind: symbol, symbol: acc))
        elif input[idx] in digits:
            var acc = 0
            while (idx < input.len) and (input[idx] in digits):
                acc *= 10
                acc += digits.find(input[idx])
                idx += 1
            output.add(Token(kind: number, number: acc))
        elif input[idx] == '#':
            idx += 1
            if idx < input.len and input[idx] == 't':
                output.add(Token(kind: boolean, boolean: true))
                idx += 1
            elif idx < input.len and input[idx] == 'f':
                output.add(Token(kind: boolean, boolean: false))
                idx += 1
        elif input[idx] == '\\':
            idx += 1
            output.add(Token(kind: lambda))
        elif input[idx] == '.':
            idx += 1
            output.add(Token(kind: dot))
        elif input[idx] == '\n':
            idx += 1
            output.add(Token(kind: newline))
        elif input[idx] == ';':
            var strength = 0
            while idx < input.len and input[idx] == ';':
                idx += 1
                strength += 1
            while idx < input.len:
                if input[idx] == ';':
                    var end_strength = 0
                    while input[idx] == ';' and end_strength < strength:
                        idx += 1
                        end_strength += 1
                    if end_strength >= strength:
                        break
                idx += 1
                assert(idx < input.len, "non-terminated comment")
        elif input[idx] == '\'':
            idx += 1
            assert(idx < input.len)
            let character = input[idx]
            idx += 1
            assert(idx < input.len)
            assert(input[idx] == '\'')
            idx += 1
            output.add(Token(kind: TokenKind.character, character: character))
        elif input[idx] == '"':
            idx += 1
            var acc = ""
            while input[idx] != '"':
                acc.add(input[idx])
                idx += 1
                assert(idx < input.len, "string: " & acc & ", initialised but not terminated")
            idx += 1
            output.add(Token(kind: str, str: acc))
        elif input[idx] == ',':
            idx += 1
            output.add(Token(kind: delimiter))
        elif input[idx] == '`':
            idx += 1
            output.add(Token(kind: quote))
        else:
            #skip whitespace and other non-recognised junk (this may later want to separate whitespace from junk and error on junk)
            idx += 1
    output.add(Token(kind: eof))
    #echo output
    return output.expand_includes()

proc parseTerm(input: seq[Token], idx: var int): Term

proc parseAbstraction(input: seq[Token], idx: var int): Abstraction

proc parseAtom(input: seq[Token], idx: var int): Atom =
    if input[idx].kind == symbol:
        idx += 1
        return Atom(kind: 0, symbol: Symbol(kind: pure, symbol: input[idx-1].symbol))
    elif input[idx].kind == number:
        idx += 1
        return Atom(kind: 0, symbol: Symbol(kind: io_int, io_int: input[idx-1].number))
    elif input[idx].kind == boolean:
        idx += 1
        return Atom(kind: 0, symbol: Symbol(kind: io_bool, io_bool: input[idx-1].boolean))
    elif input[idx].kind == pair_paren and input[idx].pair_open == true:
        idx += 1
        let term1 = parseTerm(input, idx)
        assert(input[idx].kind == delimiter)
        idx += 1
        let term2 = parseTerm(input, idx)
        assert(input[idx].kind == pair_paren and input[idx].pair_open == false)
        idx += 1
        return Atom(kind: 0, symbol: Symbol(kind: io_pair, io_pair: (term1, term2)))
    elif input[idx].kind == church_paren and input[idx].church_open == true:
        idx += 1
        var list: seq[Term] = @[]
        while true:
            list.add(parseTerm(input, idx))
            if input[idx].kind != delimiter:
                break
            idx += 1
        assert(input[idx].kind == church_paren and input[idx].church_open == false)
        idx += 1
        return Atom(kind: 0, symbol: Symbol(kind: io_church_list, io_church_list: list))
    elif input[idx].kind == scott_paren and input[idx].scott_open == true:
        idx += 1
        var list: seq[Term] = @[]
        while true:
            list.add(parseTerm(input, idx))
            if input[idx].kind != delimiter:
                break
            idx += 1
        assert(input[idx].kind == scott_paren and input[idx].scott_open == false)
        idx += 1
        return Atom(kind: 0, symbol: Symbol(kind: io_scott_list, io_scott_list: list))
    elif input[idx].kind == character:
        idx += 1
        return Atom(kind: 0, symbol: Symbol(kind: io_char, io_char: input[idx-1].character))
    elif input[idx].kind == str:
        idx += 1
        return Atom(kind: 0, symbol: Symbol(kind: io_string, io_string: input[idx-1].str))
    elif input[idx].kind == paren and input[idx].open == true:
        idx += 1
        let term = parseTerm(input, idx)
        assert(input[idx].kind == paren and input[idx].open == false)
        idx += 1
        return Atom(kind: 1, term: term)
    elif input[idx].kind == lambda:
        return Atom(kind: 2, abstraction: parseAbstraction(input, idx))
    elif input[idx].kind == quote:
        idx += 1
        let quoted = parseAtom(input, idx)
        assert(quoted.kind == 0 and quoted.symbol.kind != pure and quoted.symbol.kind != iofunc, "can only use \"`\" to quote io literals")
        case quoted.symbol.kind:
            of pure:
                assert(false, "unreachable")
            of iofunc:
                assert(false, "unreachable")
            of io_int:
                return Atom(kind: 1, term: Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: iofunc, iofunc: 1))), atom: quoted)))
            of io_pair:
                return Atom(kind: 1, term: Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: iofunc, iofunc: 3))), atom: quoted)))
            of io_bool:
                return Atom(kind: 1, term: Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: iofunc, iofunc: 5))), atom: quoted)))
            of io_church_list:
                return Atom(kind: 1, term: Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: iofunc, iofunc: 7))), atom: quoted)))
            of io_scott_list:
                return Atom(kind: 1, term: Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: iofunc, iofunc: 9))), atom: quoted)))
            of io_char:
                return Atom(kind: 1, term: Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: iofunc, iofunc: 11))), atom: quoted)))
            of io_string:
                return Atom(kind: 1, term: Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 0, symbol: Symbol(kind: iofunc, iofunc: 13))), atom: quoted)))
    else:
        assert(false, "malformed atom")


proc parseApplication(input: seq[Token], idx: var int): Application =
    var flat: seq[Atom]
    while input[idx].kind in [symbol, paren, lambda, pair_paren, church_paren, scott_paren, character, str, number, boolean, quote]:
        if input[idx].kind == paren and input[idx].open == false:
            break
        if input[idx].kind == pair_paren and input[idx].pair_open == false:
            break
        if input[idx].kind == church_paren and input[idx].church_open == false:
            break
        if input[idx].kind == scott_paren and input[idx].scott_open == false:
            break
        flat.add(parseAtom(input, idx))
    proc unflatten(input: var seq[Atom]): Application =
        if input.len == 1:
            return Application(is_atom: true, value: input[0])
        let atom = input[input.high]
        input.del(input.high)
        return Application(is_atom: false, application: unflatten(input), atom: atom)
    return unflatten(flat)

proc parseAbstraction(input: seq[Token], idx: var int): Abstraction =
    assert(input[idx] == Token(kind: lambda))
    idx += 1
    assert(input[idx].kind == symbol)
    let symbol = Symbol(kind: pure, symbol: input[idx].symbol)
    idx += 1
    assert(input[idx].kind == dot)
    idx += 1
    let term = parseTerm(input, idx)
    return Abstraction(input: symbol, output: term)

proc parseTerm(input: seq[Token], idx: var int): Term =
    if input[idx].kind in [eof, dot, define, paren, church_paren, scott_paren, newline, delimiter]:
        if input[idx].kind == paren and input[idx].open == true:
            discard
        elif input[idx].kind == church_paren and input[idx].church_open == true:
            discard
        elif input[idx].kind == scott_paren and input[idx].scott_open == true:
            discard
        else:
            #echo input[idx..idx+20]
            #echo idx
            #echo input[idx]
            assert(false, "malformed term")
    if input[idx] == Token(kind: lambda):
        return Term(is_application: false, abstraction: parseAbstraction(input, idx))
    return Term(is_application: true, application: parseApplication(input, idx))

proc parseDefinition(input: seq[Token], idx: var int): Definition =
    assert(input[idx] == Token(kind: define))
    idx += 1
    let def_symbol = input[idx]
    assert(def_symbol.kind == symbol)
    idx += 1
    return (Definition(symbol: Symbol(kind: pure, symbol: def_symbol.symbol), term: parseTerm(input, idx)))

proc parseStatement(input: seq[Token], idx: var int): Statement =
    if input[idx] == Token(kind: define):
        return Statement(is_term: false, definition: parseDefinition(input, idx))
    return Statement(is_term: true, term: parseTerm(input, idx))



proc contains(binding: seq[(Symbol, Term)], symbol: Symbol): bool =
    for i in binding:
        if i[0] == symbol: return true
    return false

proc `[]`(binding: seq[(Symbol, Term)], symbol: Symbol): Term =
    for i in binding:
        if i[0] == symbol: return i[1]
    assert(false, "attempting to find binding for unbound symbol")

proc up_to(binding: seq[(Symbol, Term)], symbol: Symbol): seq[(Symbol, Term)] =
    var output: seq[(Symbol, Term)]
    for i in binding:
        if i[0] == symbol: return output
        output.add(i)
    assert(false, "attempting to find binding for unbound symbol")

proc expand(term: var Term, bound_definitions: seq[(Symbol, Term)])

proc expand(abstraction: var Abstraction, bound_definitions: seq[(Symbol, Term)])

proc expand(atom: var Atom, bound_definitions: seq[(Symbol, Term)]) =
    case atom.kind:
        of 0:
            let symbol = atom.symbol
            if bound_definitions.contains(atom.symbol):
                atom = Atom(kind: 1, term: bound_definitions[symbol])
                expand(atom, bound_definitions.up_to(symbol))
            elif atom.symbol.kind == pure and io_func_names.contains(atom.symbol.symbol):
                atom = Atom(kind: 0, symbol: Symbol(kind: io_func, io_func: io_func_names.find(atom.symbol.symbol)))
        of 1:
            expand(atom.term, bound_definitions)
        of 2:
            expand(atom.abstraction, bound_definitions)
        else:
            assert(false, "invalid atom")

proc expand(application: var Application, bound_definitions: seq[(Symbol, Term)]) =
    if application.is_atom:
        expand(application.value, bound_definitions)
    else:
        expand(application.application, bound_definitions)
        expand(application.atom, bound_definitions)

proc expand(abstraction: var Abstraction, bound_definitions: seq[(Symbol, Term)]) =
    assert(not bound_definitions.contains(abstraction.input), "lambda functions cannot contain bound definitions in their input")
    expand(abstraction.output, bound_definitions)

proc expand(term: var Term, bound_definitions: seq[(Symbol, Term)]) =
    if term.is_application:
        expand(term.application, bound_definitions)
    else:
        expand(term.abstraction, bound_definitions)


proc parseProgram(input: seq[Token]): seq[Term] =
    var
        idx = 0
        output: seq[Term] = @[]
    while input[idx].kind == newline:
        idx += 1
    var table: seq[(Symbol, Term)]
    while input[idx].kind != eof:
        var statement = parseStatement(input, idx)
        if statement.is_term:
            expand(statement.term, table)
            output.add(statement.term)
        else:
            table.add((statement.definition.symbol, statement.definition.term))
        while input[idx].kind == newline:
            idx += 1
    return output

func union[T](a, b: seq[T]): seq[T] =
    for i in a:
        if not result.contains(i):
            result.add(i)
    for i in b:
        if not result.contains(i):
            result.add(i)

proc intersection[T](a, b: seq[T]): seq[T] =
    var output: seq[T]
    for i in a:
        if i in b:
            output.add(i)
    return output

proc subtract[T](a, b: seq[T]): seq[T] =
    var
        output: seq[T] = a
    for i in b:
        while i in output:
            output.del(output.find(i))
    return output

func FV(M: Abstraction): seq[Symbol]

func FV(M: Symbol): seq[Symbol] =
    @[M]

func FV(M: Atom): seq[Symbol] =
    if M.kind == 0:
        return FV(M.symbol)
    elif M.kind == 1:
        return FV(M.term)
    elif M.kind == 2:
        return FV(M.abstraction)
    else:
        assert(false, "malformed Atom")

func FV(M: Application): seq[Symbol] =
    if M.is_atom:
        return FV(M.value)
    return union(FV(M.application), FV(M.atom))

func FV(M: Abstraction): seq[Symbol] =
    return subtract(FV(M.output), FV(M.input))

func FV(M: Term): seq[Symbol] =
    if M.is_application:
        return FV(M.application)
    return FV(M.abstraction)

func BV(M: Abstraction): seq[Symbol]

func BV(M: Symbol): seq[Symbol] =
    return @[]

func BV(M: Atom): seq[Symbol] =
    if M.kind == 0:
        return BV(M.symbol)
    elif M.kind == 1:
        return BV(M.term)
    elif M.kind == 2:
        return BV(M.abstraction)
    else:
        assert(false, "malformed Atom")

func BV(M: Application): seq[Symbol] =
    if M.is_atom:
        return BV(M.value)
    return union(BV(M.application), BV(M.atom))

func BV(M: Abstraction): seq[Symbol] =
    return union(FV(M.input), BV(M.output))

func BV(M: Term): seq[Symbol] =
    if M.is_application:
        return BV(M.application)
    return BV(M.abstraction)

func contains_callable_iofuncs(term: Term, final_parent: Term): bool
func contains_callable_iofuncs(abstraction: Abstraction, final_parent: Term): bool

func contains_callable_iofuncs(application: Application, final_parent: Term): bool =
    if application.is_atom:
        case application.value.kind:
            of 0:
                return false
            of 1:
                return contains_callable_iofuncs(application.value.term, final_parent)
            of 2:
                return contains_callable_iofuncs(application.value.abstraction, final_parent)
            else:
                assert(false, "malformed atom")
    elif application.application.is_atom:
        let
            lhs = application.application.value
            rhs = application.atom
        case lhs.kind:
            of 0:
                if lhs.symbol.kind == iofunc and (iofuncs[lhs.symbol.iofunc](rhs, final_parent) != Term(is_application: true, application: Application(is_atom: true, value: rhs))): return true
                return contains_callable_iofuncs(Application(is_atom: true, value: application.atom), final_parent)
            of 1:
                return contains_callable_iofuncs(lhs.term, final_parent)
            of 2:
                return contains_callable_iofuncs(lhs.abstraction, final_parent)
            else:
                assert(false, "malformed atom")
    else:
        return contains_callable_iofuncs(application.application, final_parent)

func contains_callable_iofuncs(abstraction: Abstraction, final_parent: Term): bool =
    return contains_callable_iofuncs(abstraction.output, final_parent)

func contains_callable_iofuncs(term: Term, final_parent: Term): bool =
    if term.is_application:
        return contains_callable_iofuncs(term.application, final_parent)
    return contains_callable_iofuncs(term.abstraction, final_parent)

func apply_iofuncs(term: Term, final_parent: Term): Term
func apply_iofuncs(abstraction: Abstraction, final_parent: Term): Abstraction

func apply_iofuncs(atom: Atom, final_parent: Term): Atom =
    case atom.kind:
        of 0:
            return atom
        of 1:
            return Atom(kind: 1, term: apply_iofuncs(atom.term, final_parent))
        of 2:
            return Atom(kind: 2, abstraction: apply_iofuncs(atom.abstraction, final_parent))
        else:
            assert(false, "malformed atom")

func apply_iofuncs(application: Application, final_parent: Term): Application =
    if application.is_atom:
        return Application(is_atom: true, value: apply_iofuncs(application.value, final_parent))
    if application.application.is_atom:
        let lhs = application.application.value
        if lhs.kind == 0 and lhs.symbol.kind == iofunc:
            return Application(is_atom: true, value: Atom(kind: 1, term: iofuncs[lhs.symbol.iofunc](application.atom, final_parent)))
        return Application(is_atom: false, application: Application(is_atom: true, value: apply_iofuncs(lhs, final_parent)), atom: apply_iofuncs(application.atom, final_parent))
    return Application(is_atom: false, application: apply_iofuncs(application.application, final_parent), atom: apply_iofuncs(application.atom, final_parent))

func apply_iofuncs(abstraction: Abstraction, final_parent: Term): Abstraction =
    return Abstraction(input: abstraction.input, output: apply_iofuncs(abstraction.output, final_parent))

func apply_iofuncs(term: Term, final_parent: Term): Term =
    if term.is_application:
        return Term(is_application: true, application: apply_iofuncs(term.application, final_parent))
    return Term(is_application: false, abstraction: apply_iofuncs(term.abstraction, final_parent))

func replace_unbound(abstraction: Abstraction, symbol_from, symbol_to: Atom): Abstraction
func replace_unbound(term: Term, symbol_from, symbol_to: Atom): Term

func replace_unbound(atom: Atom, symbol_from, symbol_to: Atom): Atom =
    case atom.kind:
        of 0:
            if atom == symbol_from: return symbol_to
            else: return atom
        of 1:
            return Atom(kind: 1, term: atom.term.replace_unbound(symbol_from, symbol_to))
        of 2:
            return Atom(kind: 2, abstraction: atom.abstraction.replace_unbound(symbol_from, symbol_to))
        else:
            assert(false, "malformed atom")

func replace_unbound(application: Application, symbol_from, symbol_to: Atom): Application =
    if application.is_atom:
        return Application(is_atom: true, value: application.value.replace_unbound(symbol_from, symbol_to))
    else:
        return Application(is_atom: false, application: application.application.replace_unbound(symbol_from, symbol_to), atom: application.atom.replace_unbound(symbol_from, symbol_to))

func replace_unbound(abstraction: Abstraction, symbol_from, symbol_to: Atom): Abstraction =
    if abstraction.input == symbol_from.symbol:
        return abstraction
    return Abstraction(input: abstraction.input, output: abstraction.output.replace_unbound(symbol_from, symbol_to))

func replace_unbound(term: Term, symbol_from, symbol_to: Atom): Term =
    if term.is_application:
        return Term(is_application: true, application: replace_unbound(term.application, symbol_from, symbol_to))
    return Term(is_application: false, abstraction: replace_unbound(term.abstraction, symbol_from, symbol_to))

func replace_bound(term: Term, symbol_from, symbol_to: Atom): Term
func replace_bound(abstraction: Abstraction, symbol_from, symbol_to: Atom): Abstraction

func replace_bound(atom: Atom, symbol_from, symbol_to: Atom): Atom =
    case atom.kind:
        of 0:
            return atom
        of 1:
            return Atom(kind: 1, term: atom.term.replace_bound(symbol_from, symbol_to))
        of 2:
            return Atom(kind: 2, abstraction: atom.abstraction.replace_bound(symbol_from, symbol_to))
        else:
            assert(false, "malformed atom")

func replace_bound(application: Application, symbol_from, symbol_to: Atom): Application =
    if application.is_atom:
        return Application(is_atom: true, value: application.value.replace_bound(symbol_from, symbol_to))
    else:
        return Application(is_atom: false, application: application.application.replace_bound(symbol_from, symbol_to), atom: application.atom.replace_bound(symbol_from, symbol_to))

func replace_bound(abstraction: Abstraction, symbol_from, symbol_to: Atom): Abstraction =
    if abstraction.input == symbol_from.symbol:
        return Abstraction(input: symbol_to.symbol, output: abstraction.output.replace_unbound(symbol_from, symbol_to))
    return Abstraction(input: abstraction.input, output: abstraction.output.replace_bound(symbol_from, symbol_to))

func replace_bound(term: Term, symbol_from, symbol_to: Atom): Term =
    if term.is_application:
        return Term(is_application: true, application: replace_bound(term.application, symbol_from, symbol_to))
    return Term(is_application: false, abstraction: replace_bound(term.abstraction, symbol_from, symbol_to))

func alpha_rename_abstraction(abstraction: Abstraction, symbol_from: Symbol, final_parent: Term): Abstraction =
    if not (symbol_from in BV(abstraction.output)) and symbol_from != abstraction.input:
        return abstraction
    var symbol_to: Symbol = symbol_from
    while symbol_to in union(FV(final_parent), BV(abstraction.output)):
        symbol_to.instance += 1
    if symbol_from == abstraction.input:
        return Abstraction(input: symbol_to, output: abstraction.output.replace_unbound(Atom(kind: 0, symbol: symbol_from), Atom(kind: 0, symbol: symbol_to)))
    else:
        return Abstraction(input: abstraction.input, output: abstraction.output.replace_bound(Atom(kind: 0, symbol: symbol_from), Atom(kind: 0, symbol: symbol_to)))

func beta_reduce_step(term: Term, final_parent: Term): Term

func beta_reduce_step(abstraction: Abstraction, final_parent: Term): Abstraction

func beta_reduce_step(application: Application, final_parent: Term): Term =
    if application.is_atom:
        let atom = application.value
        case atom.kind:
            of 0:
                return Term(is_application: true, application: application)
            of 1:
                return atom.term
            of 2:
                return Term(is_application: false, abstraction: atom.abstraction)
            else:
                assert(false, "malformed atom")
    elif application.application.is_atom:
        let
            lhs = application.application.value
            rhs = application.atom
        case lhs.kind:
            of 0:
                #left hand side is already a symbol
                #if the symbol is an iofunc, delta-reduce it
                if lhs.symbol.kind == iofunc:
                    let output = iofuncs[lhs.symbol.iofunc](rhs, final_parent)
                    if reduce(output) != reduce(Term(is_application: true, application: Application(is_atom: true, value: rhs))):
                        return output
                #otherwise reduce the right hand side
                case rhs.kind:
                    of 0:
                        if lhs.symbol.kind == iofunc:
                            #attempt to reduce the delta-rule
                            let iofunc_application = apply_iofuncs(application, final_parent)
                            if iofunc_application.value.term != Term(is_application: true, application: Application(is_atom: true, value: rhs)):
                                return iofunc_application.value.term
                        #already beta-reduced
                        return Term(is_application: true, application: application)
                    of 1:
                        #reduce the right hand side
                        if rhs.term.is_application and rhs.term.application.is_atom:
                            return Term(is_application: true, application: Application(is_atom: false, application: application.application, atom: application.atom.term.application.value))
                        if not rhs.term.is_application:
                            return Term(is_application: true, application: Application(is_atom: false, application: application.application, atom: Atom(kind: 2, abstraction: rhs.term.abstraction)))
                        return Term(is_application: true, application: Application(is_atom: false, application: application.application, atom: Atom(kind: 1, term: beta_reduce_step(rhs.term, final_parent))))
                    of 2:
                        return Term(is_application: true, application: Application(is_atom: false, application: application.application, atom: Atom(kind: 2, abstraction: beta_reduce_step(rhs.abstraction, final_parent))))
                    else:
                        assert(false, "malformed atom")
            of 1:
                #left hand side is a term
                if lhs.term.is_application:
                    return Term(is_application: true, application: Application(is_atom: false, application: lhs.term.application, atom: rhs))
                else:
                    return Term(is_application: true, application: Application(is_atom: false, application: Application(is_atom: true, value: Atom(kind: 2, abstraction: lhs.term.abstraction)), atom: rhs))
            of 2:
                #left hand side is an abstraction
                #apply the abstraction
                var
                    abstraction = lhs.abstraction
                    input = rhs
                    to_rename = intersection(FV(input), BV(abstraction.output))
                while len(to_rename) > 0:
                    #alpha rename the first variable in to_rename
                    abstraction = abstraction.alpha_rename_abstraction(to_rename[0], final_parent)
                    to_rename = intersection(FV(input), BV(abstraction.output))
                #perform the actual function application
                return abstraction.output.replace_unbound(Atom(kind: 0, symbol: abstraction.input), application.atom)
            else:
                assert(false, "malformed atom")
    else:
        let
            reduced_lhs_term = beta_reduce_step(application.application, final_parent)
            reduced_lhs = if reduced_lhs_term.is_application: reduced_lhs_term.application else: Application(is_atom: true, value: Atom(kind: 2, abstraction: reduced_lhs_term.abstraction))
        if reduced_lhs != application.application:
            return Term(is_application: true, application: Application(is_atom: false, application: reduced_lhs, atom: application.atom))
        #lhs is already reduced
        #reduce rhs
        let rhs = application.atom
        case rhs.kind:
            of 0:
                #rhs already reduced
                return Term(is_application: true, application: application)
            of 1:
                #reduce rhs
                if rhs.term.is_application and rhs.term.application.is_atom:
                    return Term(is_application: true, application: Application(is_atom: false, application: application.application, atom: rhs.term.application.value))
                if not rhs.term.is_application:
                    return Term(is_application: true, application: Application(is_atom: false, application: application.application, atom: Atom(kind: 2, abstraction: rhs.term.abstraction)))
                return Term(is_application: true, application: Application(is_atom: false, application: application.application, atom: Atom(kind: 1, term: beta_reduce_step(rhs.term, final_parent))))
            of 2:
                #reduce rhs
                return Term(is_application: true, application: Application(is_atom: false, application: application.application, atom: Atom(kind: 2, abstraction: beta_reduce_step(rhs.abstraction, final_parent))))
            else:
                assert(false, "malformed atom")

func beta_reduce_step(abstraction: Abstraction, final_parent: Term): Abstraction =
    assert(abstraction.input.kind == pure, "impure (io) symbols are not permitted to be bound by abstractions")
    return Abstraction(input: abstraction.input, output: beta_reduce_step(abstraction.output, final_parent))

func beta_reduce_step(term: Term, final_parent: Term): Term =
    if term.is_application:
        return beta_reduce_step(term.application, final_parent)
    else:
        return Term(is_application: false, abstraction: beta_reduce_step(term.abstraction, final_parent))

func beta_reduce(term: Term, final_parent: Term): Term =
    var output: Term = term
    var next_term: Term = beta_reduce_step(term, final_parent)
    while next_term != output:
        output = next_term
        next_term = beta_reduce_step(next_term, final_parent)
    return output

func eta_reduce_step(term: Term): Term
func eta_reduce_step(abstraction: Abstraction): Term

func eta_reduce_step(atom: Atom): Atom =
    case atom.kind:
        of 0:
            return atom
        of 1:
            return Atom(kind: 1, term: eta_reduce_step(atom.term))
        of 2:
            let new_atom = Atom(kind: 1, term: eta_reduce_step(atom.abstraction))
            if new_atom.term.is_application: return new_atom
            else:
                return Atom(kind: 2, abstraction: new_atom.term.abstraction)
        else:
            assert(false, "malformed atom")

func eta_reduce_step(application: Application): Application =
    if application.is_atom:
        return Application(is_atom: true, value: eta_reduce_step(application.value))
    return Application(is_atom: false, application: eta_reduce_step(application.application), atom: eta_reduce_step(application.atom))

func eta_reduce_step(abstraction: Abstraction): Term =
    if abstraction.output.is_application and not abstraction.output.application.is_atom and abstraction.output.application.atom.kind == 0 and abstraction.output.application.atom.symbol == abstraction.input:
        let candidate = abstraction.output.application.application
        if FV(candidate) == FV(abstraction):
            return Term(is_application: true, application: candidate)
    return Term(is_application: false, abstraction: Abstraction(input: abstraction.input, output: eta_reduce_step(abstraction.output)))

func eta_reduce_step(term: Term): Term =
    if term.is_application:
        return Term(is_application: true, application: eta_reduce_step(term.application))
    return eta_reduce_step(term.abstraction)

func eta_reduce(term: Term): Term =
    var
        output = term
        next = eta_reduce_step(output)
    next = beta_reduce(next, next) #Needed to recanonise AST since eta_reduction can undo AST canonisation
    while output != next:
        output = next
        next = eta_reduce_step(next)
        next = beta_reduce(next, next)
    return output

func reduce(term: Term): Term =
    var
        output = term
        old_output = term
    output = beta_reduce(output, output)
    output = eta_reduce(output)
    while output != old_output:
        old_output = output
        #output = output.apply_iofuncs(output)
        output = output.beta_reduce(output)
        output = output.eta_reduce()
    return output

func pretty(abstraction: Abstraction): string

func pretty(symbol: Symbol): string =
    case symbol.kind:
        of pure:
            if symbol.instance == 0: return symbol.symbol
            var output = symbol.symbol
            output.add("'")
            output.add($symbol.instance)
            return output
        of iofunc:
            if symbol.instance == 0: return iofunc_names[symbol.iofunc]
            var output = iofunc_names[symbol.iofunc]
            output.add("'")
            output.add($symbol.instance)
            return output
        of io_int:
            if symbol.instance == 0: return $symbol.io_int
            var output = $symbol.io_int
            output.add("'")
            output.add($symbol.instance)
            return output
        of io_pair:
            var output = "<"
            output.add(pretty(symbol.io_pair[0]))
            output.add(", ")
            output.add(pretty(symbol.io_pair[1]))
            output.add(">")
            if symbol.instance == 0: return output
            output.add("'")
            output.add($symbol.instance)
            return output
        of io_bool:
            if symbol.instance == 0: return $symbol.io_bool
            var output = $symbol.io_bool
            output.add("'")
            output.add($symbol.instance)
            return output
        of io_church_list:
            var output = "["
            for i in symbol.io_church_list:
                output.add(pretty(i))
                output.add(", ")
            output[output.high-1] = ']'
            if symbol.instance == 0: return output
            output.add("'")
            output.add($symbol.instance)
            return output
        of io_scott_list:
            var output = "{"
            for i in symbol.io_scott_list:
                output.add(pretty(i))
                output.add(", ")
            output[output.high-1] = '}'
            if symbol.instance == 0: return output
            output.add("'")
            output.add($symbol.instance)
            return output
        of io_char:
            if symbol.instance == 0: return "'" & $symbol.io_char & "'"
            var output = "'" & $symbol.io_char & "'"
            output.add("'")
            output.add($symbol.instance)
            return output
        of io_string:
            if symbol.instance == 0: return "\"" & $symbol.io_string & "\""
            var output = "\"" & $symbol.io_string & "\""
            output.add("'")
            output.add($symbol.instance)
            return output

func pretty(atom: Atom): string =
    case atom.kind:
        of 0:
            return pretty(atom.symbol)
        of 1:
            var output = "("
            output.add(pretty(atom.term))
            output.add(")")
            return output
        of 2:
            var output = "("
            output.add(pretty(atom.abstraction))
            output.add(")")
            return output
        else:
            assert(false, "malformed atom")

func pretty(application: Application): string =
    if application.is_atom:
        return pretty(application.value)
    var output = ""
    output.add(pretty(application.application))
    output.add(" ")
    output.add(pretty(application.atom))
    return output

func pretty(abstraction: Abstraction): string =
    var output = "\\"
    output.add(pretty(abstraction.input))
    output.add(" . ")
    output.add(pretty(abstraction.output))
    return output

func pretty(term: Term): string =
    if term.is_application: return pretty(term.application)
    return pretty(term.abstraction)


proc repl() =
    echo "PureLam REPL interface:"
    var
        program = ""
        tokens: seq[Token] = @[]
        oldAST: seq[Term] = @[]
        AST: seq[Term] = @[]
    while true:
        let newLine = readLine(stdin)
        if newLine == "quit": break
        if newLine == "reset": program = ""; inputs = @[]; continue
        program.add("\n" & newLine)
        tokens = program.tokenise()
        AST = tokens.parseProgram()
        if AST != oldAST: echo(pretty(reduce(AST[AST.high])))
        else: echo "-"
        oldAST = AST

proc main() =
    if len(commandLineParams()) == 0:
        echo "Error: no arguments provided"
        echo "Intended Usages:"
        echo "    | PureLam repl        (for repl interface)"
        echo "    | PureLam <filepath>  (for file interface)"
        return
    if commandLineParams()[0] == "repl":
        repl()
        return
    let
        filepath = commandLineParams()[0]
        program = readFile(filepath)
        tokens = program.tokenise()
        AST = tokens.parseProgram()
    filesRead.add(filepath)
    echo("")
    for i in AST:
        echo(pretty(reduce(i)))
        echo("")
    return

main()
