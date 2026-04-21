## RUST FEATURE COVERAGE SCORECARD (v0.21)

Comprehensive table — every Rust feature Li hasn't rejected,
mapped to its aski v0.21 expression. Items explicitly OUT by
Li are marked accordingly.

LEGEND:  L = landed · P = proposed (see refs) · U = unspec'd ·
         OUT = confirmed out (design.md citation)

PRIMITIVES
  U8–U64 I8–I64 F32 F64 Bool String Char Vec Option Box Result
    L — in Primitive::all() or equivalent
  Unit as value — U (Unit variant exists; literal form open)
  U128 / I128 — U
  Usize / Isize — U
  &str borrowed slice — U (aski has String; no &str distinction)
  Never / `!` — L (§N2 — MERGED 2026-04-21, zero-arity primitive)
  Array                                   L — {Array T N} (§S11 — MERGED 2026-04-21)
  Rc / Arc / Cell / RefCell / Mutex / RwLock — U
  HashMap / BTreeMap / HashSet — U (type applications of stdlib types OK)

COMPOUND TYPES
  Struct (named fields)                  L  — Name.struct
  Struct (self-typed fields)              L
  Enum (bare / data / struct variants)    L  — Name.enum
  Newtype                                 L  — Name.newtype
  Nested enum / struct                    L  — (| |) / {| |} in body
  Tuple                                   OUT — design.md §No Tuples
  Array [T; N]                            L  — {Array T N} (§S11, MERGED 2026-04-21)
  Slice [T]                               U  — §U5 (outliers-v021.md)
  Union                                   U

REFERENCES & POINTERS
  &T shared borrow                        L
  &mut T                                  L  — `~&T`
  'a lifetime generics                    OUT-ish — replaced by origins
  'static                                 L  — 'Static place name (§N1 MERGED 2026-04-21)
  Place-based origins 'Place              L
  View types {| fields |}                 L
  Borrow of place expression              L  — §C7 (MERGED 2026-04-21)
  *const T / *mut T raw pointer           U

CALLABLE TYPES
  fn pointer fn(A) -> B                   U
  Fn / FnMut / FnOnce traits              U
  Closure literal |x| body                P — §S4 Position A MERGED; B/C outliers
  Callable trait (Position A)             L  — stdlib trait, zero grammar change

TYPE SYSTEM
  Generic type params {$Value}            L
  Trait bounds $Value{Clone Debug}        L
  Super-traits                            L
  Associated types (decl + binding)       L
  Associated consts                       L  — §S9 MERGED 2026-04-21
  Method-level generics                   L
  Where clauses                           U
  GATs                                    U
  HRTB for<'a>                            U
  const generics                          U
  impl Trait (input / output)             U
  dyn Trait                               P  — §U14 sigil PICK-AND-MERGE;
                                             §S6 semantics in outliers
  PhantomData                             U  — aski tracks params structurally
  Higher-kinded types                     U  — §U20 (outliers)
  Dependent types                         U  — §U21 (outliers)

CONTROL FLOW
  match                                   L
  if / else (via match on Bool)           L-idiom — §C4 MERGED 2026-04-21
  if let / while let                      L-idiom — §C4 MERGED 2026-04-21
  while                                   L
  for                                     L  — iteration
  loop (infinite)                         U  — §U19 (outliers)
  break / continue / labels               P  — §U13 PICK-AND-MERGE
  return / ?                              L
  async / await                           U

EXPRESSIONS
  + - * %                                 L
  /                                       L  — v0.21 (§C5, landed 2026-04-20)
  == != < > <= >=                         L
  && ||                                   L
  Bitwise & | ^ << >>                     L-via-methods — §S5 MERGED 2026-04-21
  Unary -                                 L  — v0.21 (§C6)
  Unary !                                 L  — v0.21 (§C6)
  Unary * (deref)                         L  — §U1 ACCEPTED 2026-04-21
  Assignment =                            U  — §U7 (outliers; methods today)
  Compound assignment +=                  U  — §U7 (outliers)
  Method call .method(…)                  L
  Field access .Field                     L
  Cast as                                 L-via-methods — §S7 MERGED 2026-04-21
  Range .. ..=                            L  — §S2 MERGED 2026-04-21
  Array literal [x; n]                    U  — §U4 (outliers)
  Tuple literal                           OUT
  Struct literal                          L  — StructConstruct
  Block as expression                     L  — InlineEval
  Closure literal                         P — §S4 Position A only; B/C outliers
  Macro invocation foo!()                 U

PATTERNS
  Wildcard _                              L  — landed 2026-04-19
  Variant match                           L
  Variant bind                            L
  Or-pattern [A B] (variants)             L
  String literal                          L
  Literal patterns (int/float)            P  — §C3 PICK-AND-MERGE (scope)
  Struct destructuring                    P  — §U11 PICK-AND-MERGE (binding rule)
  Tuple destructuring                     OUT
  Reference pattern &x                    U
  Binding name @ pattern                  U  — `@` is visibility
  Range pattern 0..=9                     U
  Guard (if cond)                         U
  Rest ..                                 U
  General or-pattern A | B (non-variant)  U

ITEMS
  Struct / Enum / Newtype / Const         L  — per-kind .struct/.enum/etc.
  Trait / TraitImpl                       L  — .trait / .impl
  Module header                           OUT-in-source — directory = module (§II-L)
  Free function                           OUT — design.md §No Free Functions
  Inherent impl                           U  — §U9 (spec silent)
  Type alias                              U  — §S1 (user preference OUT)
  Static item                             U
  Submodule mod                           OUT-in-source — directory IS the submodule
  macro_rules                             U  — replaced by .derivation files
  Proc macros                             U  — replaced by .derivation files
  extern block                            L-alt — handled by .rfi files

VISIBILITY
  pub / public                            L  — unprefixed filename / `@` on fields
  default private                         L  — `_` filename prefix / bare field
  pub(crate) / pub(super) / pub(in path)  P  — §N4 / §U10 (deferred)

SAFETY
  unsafe                                  U  — proposed .unsafe-impl surface
  transmute                               U
  Raw pointer deref                       U

ERROR HANDLING
  Result<T, E>                            L
  Option<T>                               L
  ? try-unwrap                            L
  panic!                                  U
  Error trait                             U

STRINGS & LITERALS
  String literal "…"                      L
  Escape sequences                        L — §N8 MERGED 2026-04-21
  Raw string r"…"                          L — §N8 (triple-quote form MERGED)
  Byte string b"…"                          U
  Char literal 'x'                        OUT-replaced — Char library (§U16)
  Byte literal b'x'                       U
  Int literal (decimal)                   L
  Int literal hex/oct/bin                 L — §N8 MERGED 2026-04-21
  Numeric separators 1_000                L — §N8 MERGED 2026-04-21
  Typed integer suffix 42u32              P — §N8 (typed-suffix still open)
  Float literal                           L
  Bool literal (true / false)             U — §U2 / §U3 (outliers)

TRAITS (stdlib — mostly U, depending on stdlib buildout)
  From / Into / TryFrom / TryInto         L-via-methods — §S7 MERGED 2026-04-21
  Callable                                L-via-methods — §S4 Position A stdlib
  Counter (set/addAssign/subAssign/…)     L-via-methods — §N3 MERGED 2026-04-21
  BitOps                                  L-via-methods — §S5 MERGED 2026-04-21
  Deref                                   L-via-methods — §U1 dispatch via trait
  Clone / Copy / Debug / Display /
  PartialEq / Eq / Hash / PartialOrd /
  Ord / Default                           U — no stdlib spec yet
  AsRef / Borrow                          U
  Iterator trait                          U — iteration syntax landed
  Fn / FnMut / FnOnce                     U
  Index / IndexMut                        U
  Add / Sub / Mul / Div / Rem             U — operators bound, traits not
  Neg / Not                               P — §C6 (landed at operator level)
  Send / Sync                             U
  Drop                                    U

CONCURRENCY                               All U. Nothing spec'd.

ATTRIBUTES
  #[derive(…)]                            L-alt — .derivation surface
  #[cfg(…)]                               U     — platform-impl surfaces
  Doc comments ///                        P     — §N7 (shelved)

MODULES / NAMESPACING
  Directory = module                      L
  imports per-directory file              L
  Inline mod blocks                       OUT-in-source
  pub use re-exports                      OUT — §7.7 decomposition.md

FFI
  extern "Rust" / "C" / …                 L-alt — .rfi surface

TESTING / BENCHMARKING
  #[cfg(test)]                            L-alt — .test-impl surface
  #[bench]                                L-alt — .bench-impl surface
  Test harness                            U     — build-time wiring
