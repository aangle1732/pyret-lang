#lang pyret

provide {
  PPrintDoc: PPrintDoc,
  mt-doc: mt-doc,
  is-mt-doc: is-mt-doc,
  str: str,
  number: number,
  hardline: hardline,
  blank: blank,
  sbreak: sbreak,
  concat: concat,
  nest: nest,
  if-flat: if-flat,
  group: group,
  flow: flow,
  flow-map: flow-map,
  vert: vert,
  parens: parens,
  braces: braces,
  brackets: brackets,
  dquote: dquote,
  squote: squote,
  align: align,
  hang: hang,
  prefix: prefix,
  infix: infix,
  infix-break: infix-break,
  separate: separate,
  surround: surround,
  soft-surround: soft-surround,
  surround-separate: surround-separate,
  label-align-surround: label-align-surround,
  lparen: lparen,
  rparen: rparen,
  lbrace: lbrace,
  rbrace: rbrace,
  lbrack: lbrack,
  rbrack: rbrack,
  langle: langle,
  rangle: rangle,
  comma: comma,
  commabreak: commabreak
} end

data PPrintDoc:
  | mt-doc(flat-width :: Number, has-hardline :: Bool)
  | str(s :: String, flat-width :: Number, has-hardline :: Bool)
  | hardline(flat-width :: Number, has-hardline :: Bool)
  | blank(n :: Number, flat-width :: Number, has-hardline :: Bool)
  | concat(fst :: PPrintDoc, snd :: PPrintDoc, flat-width :: Number, has-hardline :: Bool)
  | nest(indent :: Number, d :: PPrintDoc, flat-width :: Number, has-hardline :: Bool)
  | if-flat(flat :: PPrintDoc, vert :: PPrintDoc, flat-width :: Number, has-hardline :: Bool)
  | align(d :: PPrintDoc, flat-width :: Number, has-hardline :: Bool)
  | align-spaces(n :: Number, flat-width :: Number, has-hardline :: Bool)
  | group(d :: PPrintDoc, flat-width :: Number, has-hardline :: Bool)
sharing:
  _plus(self, other):
    if is-mt-doc(self): other
    else if is-mt-doc(other): self
    else if is-concat(self):
      self.fst + (self.snd + other)
    else:
      if self.has-hardline or other.has-hardline: concat(self, other, 0, true)
      else: concat(self, other, self.flat-width + other.flat-width, false)
      end
    end
  end,
  tostring(self):
    cases(PPrintDoc) self:
      | mt-doc(_, _) => "EmptyDoc"
      | str(s, _, _) => "Str('" + s + "')"
      | hardline(_, _) => "CRLF"
      | blank(n, _, _) => "Blank(" + tostring(n) + ")"
      | concat(fst, snd, _, _) => "Concat(" + tostring(fst) + ", " + tostring(snd) + ")"
      | nest(indent, d, _, _) => "Nest(" + tostring(indent) + ", " + tostring(d) + ")"
      | if-flat(flat, vert, _, _) => "IfFlat(" + tostring(flat) + ", " + tostring(vert) + ")"
      | group(d, _, _) => "Group(" + tostring(d) + ", " + ")"
      | align(d, _, _) => "Align(" + tostring(d) + ")"
      | align-spaces(n, _, _) => "AlignSpaces(" + tostring(n) + ")"
    end
  end,
  pretty(self, width):
    format(width, self)
  end
end
data Item:
  | item(indent :: Number, is-flat :: Boolean, d :: PPrintDoc)
end
# Not needed at the moment...
# fun fits(width :: Number, items :: List<Item>) -> Bool:
#   if width < 0: false
#   else if is-empty(items): true
#   else: 
#     first = items.first
#     i = first.indent
#     m = first.is-flat
#     cases(PPrintDoc) first.d:
#       | mt-doc(_, _) => fits(width, items.rest)
#       | str(s, flat-width, _) => fits(width - flat-width, items.rest)
#       | hardline(_, _) => true
#       | blank(n, _, _) => fits(width - n, items.rest)
#       | concat(fst, snd, _, _) => fits(width, [list: item(i, m, fst), item(i, m, snd)] + items.rest)
#       | nest(_, d, _, _) => fits(width, [list: item(i, m, d)] + items.rest)
#       | align(d, _, _) => fits(width, [list: item(i, m, d)] + items.rest)
#       | if-flat(flat, vert, _, _) =>
#         if m: fits(width, [list: item(i, m, flat)] + items.rest)
#         else: fits(width, [list: item(i, m, vert)] + items.rest)
#         end
#       | align-spaces(n, _, _) =>
#         if m: fits(width, items.rest)
#         else: fits(width - n, items.rest)
#         end
#       | group(d, flat-width, has-hardline) =>
#         if has-hardline: fits(width, [list: item(i, false, d)] + items.rest)
#         else: fits(width - flat-width, items.rest)
#         end
#     end
#   end
# end
fun format(width, doc :: PPrintDoc):
  var output = [list: [list: ]]
  fun emit-text(s):
    output := [list: [list: s] + output.first] + output.rest
  end
  fun emit-spaces(n):
    emit-text(string-repeat(" ", n))
  end
  fun emit-newline(i):
    output := [list: [list: string-repeat(" ", i)]] + output
  end
  fun gen-output():
    for lists.fold(lines from [list: ], line from output):
      l = for lists.fold(acc from "", piece from line):
        piece + acc
      end
      [list: l] + lines
    end
  end
  fun process(column :: Number, items :: List<Item>) -> Nothing:
    if is-empty(items): nothing
    else:
      first = items.first
      i = first.indent
      m = first.is-flat
      cases(PPrintDoc) first.d:
        | mt-doc(_, _) => process(column, items.rest)
        | concat(fst, snd, _, _) => process(column, [list: item(i, m, fst), item(i, m, snd)] + items.rest)
        | str(s, flat-width, _) =>
          emit-text(s)
          process(column + flat-width, items.rest)
        | blank(n, _, _) =>
          emit-spaces(n)
          process(column + n, items.rest)
        | align(d, _, _) => process(column, [list: item(column, m, d)] + items.rest)
        | nest(n, d, _, _) => process(column, [list: item(i + n, m, d)] + items.rest)
        | hardline(_, _) =>
          if m: raise("Impossible for HardLine to be flat")
          else:
            emit-newline(i)
            process(i, items.rest)
          end
        | if-flat(flat, vert, _, _) =>
          process(column, [list: item(i, m, if m: flat else: vert end)] + items.rest)
        | align-spaces(n, _, _) =>
          if m: process(column, items.rest)
          else:
            emit-spaces(n)
            process(column + n, items.rest)
          end
        | group(d, flat-width, has-hardline) =>
          if m: process(column, [list: item(i, true, d)] + items.rest)
          else if has-hardline: process(column, [list: item(i, false, d)] + items.rest)
          else if (width - column) >= flat-width:
            # This used to check whether items.rest fits into the remaining space,
            # but that precludes implementing "flowing" text, which is more important.
            # If we need both behaviors, I guess I can add a flow-group...
            process(column, [list: item(i, true, d)] + items.rest)
          else:
            process(column, [list: item(i, false, d)] + items.rest)
          end
      end
    end
  end
  process(0, [list: item(0, false, group(doc, doc.flat-width, doc.has-hardline))])
  gen-output()
end

shadow mt-doc = mt-doc(0, false)
shadow hardline = hardline(0, true)
shadow align = fun(d): align(d, d.flat-width, d.has-hardline) end
shadow group = fun(d): group(d, d.flat-width, d.has-hardline) end
shadow if-flat = fun(flat, vert): if-flat(flat, vert, flat.flat-width, flat.has-hardline) end
shadow nest = fun(n, d): nest(n, d, d.flat-width, d.has-hardline) end
shadow concat = fun(fst, snd): fst + snd end
shadow blank = fun(n): blank(n, n, false) end
shadow str = fun(s): str(s, string-length(s), false) end

fun number(n :: Number): str(tostring(n)) end
lparen = str("(")
rparen = str(")")
lbrace = str("{")
rbrace = str("}")
lbrack = str("[list: ")
rbrack = str("]")
langle = str("<")
rangle = str(">")
comma = str(",")
fun sbreak(n): if-flat(blank(n), hardline) end
commabreak = comma + sbreak(1)

fun flow-map(sep, f, items):
  for lists.fold(acc from mt-doc, shadow item from items):
    if is-mt-doc(acc): f(item)
    else: acc + group(sep + f(item))
    end
  end
end
fun flow(items): flow-map(sbreak(1), fun(x): x end, items) end
fun vert(items): flow-map(hardline, fun(x): x end, items) end
fun parens(d): group(lparen + d + rparen) end
fun braces(d): group(lbrace + d + rbrace) end
fun brackets(d): group(lbrack + d + rbrack) end
str-squote = str("'")
str-dquote = str('"')
fun dquote(s): group(str-dquote + s + str-dquote) end
fun squote(s): group(str-squote + s + str-squote) end

fun hang(i, d): align(nest(i, d)) end
fun prefix(n, b, x, y): group(x + nest(n, sbreak(b) + y)) end
fun infix(n :: Number, b :: Number, op :: PPrintDoc, x :: PPrintDoc, y :: PPrintDoc):
  prefix(n, b, (x + blank(b) + op), y)
end
fun infix-break(n :: Number, b :: Number, op :: PPrintDoc, x :: PPrintDoc, y :: PPrintDoc):
  prefix(n, b, x, (op + blank(b) + y))
end
fun surround(n :: Number, b :: Number, open :: PPrintDoc, contents :: PPrintDoc, close :: PPrintDoc):
  if is-mt-doc(close): group(open + nest(n, sbreak(b) + contents))
  else: group(open + nest(n, sbreak(b) + contents) + sbreak(b) + close)
  end
end
fun soft-surround(n :: Number, b :: Number, open :: PPrintDoc, contents :: PPrintDoc, close :: PPrintDoc):
  if is-mt-doc(close): group(open + nest(n, group(sbreak(b) + contents)))
  else: group(open + nest(n, group(sbreak(b) + contents)) + group(sbreak(b) + close))
  end
end

fun separate(sep :: PPrintDoc, docs :: lists.List):
  for lists.fold(acc from mt-doc, d from docs):
    if is-mt-doc(d): acc
    else if is-mt-doc(acc): d
    else: acc + sep + d
    end
  end
end
fun surround-separate(n :: Number, b :: Number, void :: PPrintDoc, open :: PPrintDoc, sep :: PPrintDoc, close :: PPrintDoc, docs :: lists.List):
  if lists.is-empty(docs): void
  else: surround(n, b, open, separate(sep, docs), close)
  end
end

fun label-align-surround(label, open, sep, contents, close):
  group(label + align(open + align(separate(sep, contents)) + group(sbreak(0) + close)))
end

check:
  test-words = [list: "This", "is", "a", "sentence", "with", "eight", "words"].map(str)
  test = flow(test-words)

  test.pretty(40) is [list: "This is a sentence with eight words"]
  test.pretty(30) is [list: "This is a sentence with eight", "words"]
  test.pretty(20) is [list: "This is a sentence", "with eight words"]
  test.pretty(10) is [list: "This is a", "sentence", "with eight", "words"]

  fun opt-break(x, y):
    if is-empty(x): y
    else if is-empty(y): x
    else: x + (sbreak(1) + y)
    end
  end
  fun binop(left, op, right):
    group(nest(2,
        opt-break(group(opt-break(str(left), str(op))), str(right))))
  end
  fun ifthen(c, t, f):
    group(
      group(nest(2, opt-break(str("if"), c))) ^ opt-break(_, 
        group(nest(2, opt-break(str("then"), t))) ^ opt-break(_, 
          group(nest(2, opt-break(str("else"), f))))))
  end
  ifthenelse = ifthen(binop("a", "==", "b"), binop("a", "<<", "2"), binop("a", "+", "b"))
  ifthenelse.pretty(32) is [list: "if a == b then a << 2 else a + b"]
  ifthenelse.pretty(15) is [list: "if a == b", "then a << 2", "else a + b"]
  ifthenelse.pretty(10) is [list: "if a == b", "then", "  a << 2", "else a + b"]
  ifthenelse.pretty(8) is
  [list:  "if",
    "  a == b",
    "then",
    "  a << 2",
    "else",
    "  a + b" ]
  ifthenelse.pretty(7) is
  [list:  "if",
    "  a ==",
    "    b",
    "then",
    "  a <<",
    "    2",
    "else",
    "  a + b" ]
  ifthenelse.pretty(6) is
  [list:  "if",
    "  a ==",
    "    b",
    "then",
    "  a <<",
    "    2",
    "else",
    "  a +",
    "    b" ]
end
