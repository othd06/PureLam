
import std/cmdline

type
    TokenKind = enum
        paren, symbol, define, lambda, dot, newline, eof
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
            of eof:
                discard
    SymbolKind = enum
        pure, iofunc
    Symbol = object
        instance: int = 0
        case kind: SymbolKind
            of pure:
                symbol: string
            of iofunc:
                iofunc: int
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

const
    alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    digits = "0123456789"
    iofuncs: array[0, proc(value: Atom): Term {.nosideeffect.}] = []
    iofunc_names: array[0, string] = []


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

func `==`(a, b: Term): bool
func `==`(a, b: Abstraction): bool

func `==`(a, b: Atom): bool =
    if a.kind != b.kind:
        return false
    case a.kind:
        of 0: return a.symbol == b.symbol
        of 1: return a.term == b.term
        of 2: return a.abstraction == b.abstraction
        else: assert(false, "malformed atom")

func `==`(a, b: Application): bool =
    if a.is_atom != b.is_atom:
        return false
    if a.is_atom:
        return a.value == b.value
    else:
        return a.application == b.application and a.atom == b.atom

func `==`(a, b: Abstraction): bool =
    return a.input == b.input and a.output == b.output

func `==`(a, b: Term): bool =
    if a.is_application != b.is_application:
        return false
    if a.is_application:
        return a.application == b.application
    return a.abstraction == b.abstraction

proc tokenise (input: string): seq[Token] =
    var
        output: seq[Token] = @[]
        idx: int = 0
    while idx < input.len:
        if input[idx] == '(':
            idx += 1
            output.add(Token(kind: paren, open: true))
        elif input[idx] == ')':
            idx += 1
            output.add(Token(kind: paren, open: false))
        elif input[idx] in alpha:
            var acc = ""
            while (idx < input.len) and ((input[idx] in alpha) or (input[idx] in digits) or (input[idx] == '-')):
                acc.add(input[idx])
                idx += 1
            if acc == "define":
                output.add(Token(kind: define))
            else:
                output.add(Token(kind: symbol, symbol: acc))
        elif input[idx] == '\\':
            idx += 1
            output.add(Token(kind: lambda))
        elif input[idx] == '.':
            idx += 1
            output.add(Token(kind: dot))
        elif input[idx] == '\n':
            idx += 1
            output.add(Token(kind: newline))
        else:
            #skip whitespace and other non-recognised junk (this may later want to separate whitespace from junk and error on junk)
            idx += 1
    output.add(Token(kind: eof))
    return output

proc parseTerm(input: seq[Token], idx: var int): Term

proc parseAbstraction(input: seq[Token], idx: var int): Abstraction

proc parseAtom(input: seq[Token], idx: var int): Atom =
    if input[idx].kind == symbol:
        idx += 1
        return Atom(kind: 0, symbol: Symbol(kind: pure, symbol: input[idx-1].symbol))
    elif input[idx].kind == paren and input[idx].open == true:
        idx += 1
        let term = parseTerm(input, idx)
        assert(input[idx].kind == paren and input[idx].open == false)
        idx += 1
        return Atom(kind: 1, term: term)
    elif input[idx].kind == lambda:
        return Atom(kind: 2, abstraction: parseAbstraction(input, idx))
    else:
        assert(false, "malformed atom")


proc parseApplication(input: seq[Token], idx: var int): Application =
    var flat: seq[Atom]
    while input[idx].kind in [symbol, paren, lambda]:
        if input[idx].kind == paren and input[idx].open == false:
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
    if input[idx].kind in [eof, dot, define, paren, newline]:
        if input[idx].kind == paren and input[idx].open == true:
            discard
        else:
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

proc union[T](a, b: seq[T]): seq[T] =
    var output: seq[T] = @[]
    for i in a:
        if not output.contains(i):
            output.add(i)
    for i in b:
        if not output.contains(i):
            output.add(i)
    return output

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

proc FV(M: Term): seq[Symbol]

proc FV(M: Abstraction): seq[Symbol]

proc FV(M: Symbol): seq[Symbol] =
    @[M]

proc FV(M: Atom): seq[Symbol] =
    if M.kind == 0:
        return FV(M.symbol)
    elif M.kind == 1:
        return FV(M.term)
    elif M.kind == 2:
        return FV(M.abstraction)
    else:
        assert(false, "malformed Atom")

proc FV(M: Application): seq[Symbol] =
    if M.is_atom:
        return FV(M.value)
    return union(FV(M.application), FV(M.atom))

proc FV(M: Abstraction): seq[Symbol] =
    return subtract(FV(M.output), FV(M.input))

proc FV(M: Term): seq[Symbol] =
    if M.is_application:
        return FV(M.application)
    return FV(M.abstraction)

proc BV(M: Term): seq[Symbol]

proc BV(M: Abstraction): seq[Symbol]

proc BV(M: Symbol): seq[Symbol] =
    return @[]

proc BV(M: Atom): seq[Symbol] =
    if M.kind == 0:
        return BV(M.symbol)
    elif M.kind == 1:
        return BV(M.term)
    elif M.kind == 2:
        return BV(M.abstraction)
    else:
        assert(false, "malformed Atom")

proc BV(M: Application): seq[Symbol] =
    if M.is_atom:
        return BV(M.value)
    return union(BV(M.application), BV(M.atom))

proc BV(M: Abstraction): seq[Symbol] =
    return union(FV(M.input), BV(M.output))

proc BV(M: Term): seq[Symbol] =
    if M.is_application:
        return BV(M.application)
    return BV(M.abstraction)

proc contains_callable_iofuncs(term: Term): bool
proc contains_callable_iofuncs(abstraction: Abstraction): bool

proc contains_callable_iofuncs(application: Application): bool =
    if application.is_atom:
        case application.value.kind:
            of 0:
                return false
            of 1:
                return contains_callable_iofuncs(application.value.term)
            of 2:
                return contains_callable_iofuncs(application.value.abstraction)
            else:
                assert(false, "malformed atom")
    elif application.application.is_atom:
        let lhs = application.application.value
        case lhs.kind:
            of 0:
                if lhs.symbol.kind == iofunc: return true
                return contains_callable_iofuncs(Application(is_atom: true, value: application.atom))
            of 1:
                return contains_callable_iofuncs(lhs.term)
            of 2:
                return contains_callable_iofuncs(lhs.abstraction)
            else:
                assert(false, "malformed atom")
    else:
        return contains_callable_iofuncs(application.application)

proc contains_callable_iofuncs(abstraction: Abstraction): bool =
    return contains_callable_iofuncs(abstraction.output)

proc contains_callable_iofuncs(term: Term): bool =
    if term.is_application:
        return contains_callable_iofuncs(term.application)
    return contains_callable_iofuncs(term.abstraction)

proc apply_iofuncs(term: Term): Term
proc apply_iofuncs(abstraction: Abstraction): Abstraction

proc apply_iofuncs(atom: Atom): Atom =
    case atom.kind:
        of 0:
            return atom
        of 1:
            return Atom(kind: 1, term: apply_iofuncs(atom.term))
        of 2:
            return Atom(kind: 2, abstraction: apply_iofuncs(atom.abstraction))
        else:
            assert(false, "malformed atom")

proc apply_iofuncs(application: Application): Application =
    if application.is_atom:
        return Application(is_atom: true, value: apply_iofuncs(application.value))
    if application.application.is_atom:
        let lhs = application.application.value
        if lhs.kind == 0 and lhs.symbol.kind == iofunc:
            return Application(is_atom: true, value: Atom(kind: 1, term: iofuncs[lhs.symbol.iofunc](application.atom)))
        return Application(is_atom: false, application: Application(is_atom: true, value: apply_iofuncs(lhs)), atom: apply_iofuncs(application.atom))
    return Application(is_atom: false, application: apply_iofuncs(application.application), atom: apply_iofuncs(application.atom))

proc apply_iofuncs(abstraction: Abstraction): Abstraction =
    return Abstraction(input: abstraction.input, output: apply_iofuncs(abstraction.output))

proc apply_iofuncs(term: Term): Term =
    if term.is_application:
        return Term(is_application: true, application: apply_iofuncs(term.application))
    return Term(is_application: false, abstraction: apply_iofuncs(term.abstraction))

proc replace_unbound(term: Term, symbol_from, symbol_to: Atom): Term
proc replace_unbound(abstraction: Abstraction, symbol_from, symbol_to: Atom): Abstraction

proc replace_unbound(atom: Atom, symbol_from, symbol_to: Atom): Atom =
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

proc replace_unbound(application: Application, symbol_from, symbol_to: Atom): Application =
    if application.is_atom:
        return Application(is_atom: true, value: application.value.replace_unbound(symbol_from, symbol_to))
    else:
        return Application(is_atom: false, application: application.application.replace_unbound(symbol_from, symbol_to), atom: application.atom.replace_unbound(symbol_from, symbol_to))

proc replace_unbound(abstraction: Abstraction, symbol_from, symbol_to: Atom): Abstraction =
    if abstraction.input == symbol_from.symbol:
        return abstraction
    return Abstraction(input: abstraction.input, output: abstraction.output.replace_unbound(symbol_from, symbol_to))

proc replace_unbound(term: Term, symbol_from, symbol_to: Atom): Term =
    if term.is_application:
        return Term(is_application: true, application: replace_unbound(term.application, symbol_from, symbol_to))
    return Term(is_application: false, abstraction: replace_unbound(term.abstraction, symbol_from, symbol_to))

proc replace_bound(term: Term, symbol_from, symbol_to: Atom): Term
proc replace_bound(abstraction: Abstraction, symbol_from, symbol_to: Atom): Abstraction

proc replace_bound(atom: Atom, symbol_from, symbol_to: Atom): Atom =
    case atom.kind:
        of 0:
            return atom
        of 1:
            return Atom(kind: 1, term: atom.term.replace_bound(symbol_from, symbol_to))
        of 2:
            return Atom(kind: 2, abstraction: atom.abstraction.replace_bound(symbol_from, symbol_to))
        else:
            assert(false, "malformed atom")

proc replace_bound(application: Application, symbol_from, symbol_to: Atom): Application =
    if application.is_atom:
        return Application(is_atom: true, value: application.value.replace_bound(symbol_from, symbol_to))
    else:
        return Application(is_atom: false, application: application.application.replace_bound(symbol_from, symbol_to), atom: application.atom.replace_bound(symbol_from, symbol_to))

proc replace_bound(abstraction: Abstraction, symbol_from, symbol_to: Atom): Abstraction =
    if abstraction.input == symbol_from.symbol:
        return Abstraction(input: symbol_to.symbol, output: abstraction.output.replace_unbound(symbol_from, symbol_to))
    return Abstraction(input: abstraction.input, output: abstraction.output.replace_bound(symbol_from, symbol_to))

proc replace_bound(term: Term, symbol_from, symbol_to: Atom): Term =
    if term.is_application:
        return Term(is_application: true, application: replace_bound(term.application, symbol_from, symbol_to))
    return Term(is_application: false, abstraction: replace_bound(term.abstraction, symbol_from, symbol_to))

proc alpha_rename_abstraction(abstraction: Abstraction, symbol_from: Symbol, final_parent: Term): Abstraction =
    if not (symbol_from in BV(abstraction.output)) and symbol_from != abstraction.input:
        return abstraction
    var symbol_to: Symbol = symbol_from
    while symbol_to in union(FV(final_parent), BV(abstraction.output)):
        symbol_to.instance += 1
    if symbol_from == abstraction.input:
        return Abstraction(input: symbol_to, output: abstraction.output.replace_unbound(Atom(kind: 0, symbol: symbol_from), Atom(kind: 0, symbol: symbol_to)))
    else:
        return Abstraction(input: abstraction.input, output: abstraction.output.replace_bound(Atom(kind: 0, symbol: symbol_from), Atom(kind: 0, symbol: symbol_to)))

proc beta_reduce_step(term: Term, final_parent: Term): Term

proc beta_reduce_step(abstraction: Abstraction, final_parent: Term): Abstraction

proc beta_reduce_step(application: Application, final_parent: Term): Term =
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
                #reduce the right hand side
                case rhs.kind:
                    of 0:
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

proc beta_reduce_step(abstraction: Abstraction, final_parent: Term): Abstraction =
    return Abstraction(input: abstraction.input, output: beta_reduce_step(abstraction.output, final_parent))

proc beta_reduce_step(term: Term, final_parent: Term): Term =
    if term.is_application:
        return beta_reduce_step(term.application, final_parent)
    else:
        return Term(is_application: false, abstraction: beta_reduce_step(term.abstraction, final_parent))

proc beta_reduce(term: Term, final_parent: Term): Term =
    var output: Term = term
    var next_term: Term = beta_reduce_step(term, final_parent)
    while next_term != output:
        output = next_term
        next_term = beta_reduce_step(next_term, final_parent)
    return output

proc eta_reduce_step(term: Term): Term
proc eta_reduce_step(abstraction: Abstraction): Term

proc eta_reduce_step(atom: Atom): Atom =
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

proc eta_reduce_step(application: Application): Application =
    if application.is_atom:
        return Application(is_atom: true, value: eta_reduce_step(application.value))
    return Application(is_atom: false, application: eta_reduce_step(application.application), atom: eta_reduce_step(application.atom))

proc eta_reduce_step(abstraction: Abstraction): Term =
    if abstraction.output.is_application and not abstraction.output.application.is_atom and abstraction.output.application.atom.kind == 0 and abstraction.output.application.atom.symbol == abstraction.input:
        let candidate = abstraction.output.application.application
        if FV(candidate) == FV(abstraction):
            return Term(is_application: true, application: candidate)
    return Term(is_application: false, abstraction: Abstraction(input: abstraction.input, output: eta_reduce_step(abstraction.output)))

proc eta_reduce_step(term: Term): Term =
    if term.is_application:
        return Term(is_application: true, application: eta_reduce_step(term.application))
    return eta_reduce_step(term.abstraction)

proc eta_reduce(term: Term): Term =
    var
        output = term
        next = eta_reduce_step(output)
    next = beta_reduce(next, next) #Needed to recanonise AST since eta_reduction can undo AST canonisation
    while output != next:
        output = next
        next = eta_reduce_step(next)
        next = beta_reduce(next, next)
    return output

proc reduce(term: Term): Term =
    var output = term
    output = beta_reduce(output, output)
    output = eta_reduce(output)
    while output.contains_callable_iofuncs():
        output = output.apply_iofuncs()
        output = output.beta_reduce(output)
        output = output.eta_reduce()
    return output

proc pretty(term: Term): string
proc pretty(abstraction: Abstraction): string

proc pretty(symbol: Symbol): string =
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

proc pretty(atom: Atom): string =
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

proc pretty(application: Application): string =
    if application.is_atom:
        return pretty(application.value)
    var output = ""
    output.add(pretty(application.application))
    output.add(" ")
    output.add(pretty(application.atom))
    return output

proc pretty(abstraction: Abstraction): string =
    var output = "\\"
    output.add(pretty(abstraction.input))
    output.add(" . ")
    output.add(pretty(abstraction.output))
    return output

proc pretty(term: Term): string =
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
        if newLine == "reset": program = ""; continue
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
    echo("")
    for i in AST:
        echo(pretty(reduce(i)))
        echo("")
    return

main()
