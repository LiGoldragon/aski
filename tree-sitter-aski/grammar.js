/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

// Aski tree-sitter grammar (v0.17 — positional dialects)
// Spec: spec/syntax-v017.aski

const PREC = {
  RETURN:      1,
  LOGICAL_OR:  2,
  LOGICAL_AND: 3,
  COMPARE:     4,
  ADD:         5,
  MULTIPLY:    6,
  PREFIX:      7,
  POSTFIX:     8,
  ACCESS:      9,
  CALL:       10,
  PATH:       11,
};

module.exports = grammar({
  name: 'aski',

  extras: $ => [
    /\s/,
    $.comment,
  ],

  word: $ => $._lower_ident,

  conflicts: $ => [
    // Statements: instance vs expr
    [$.instance_stmt, $._primary_expr],
    [$.mutation_stmt, $._primary_expr],
    // Params
    [$.param],
    // Signature params
    [$.sig_param],
    [$.sig_param, $._type],
    // Type application vs block/primary
    [$.type_application, $._primary_expr],
  ],

  rules: {
    // Module is always first — positional rule from Root.synth
    source_file: $ => seq(
      $.module_decl,
      repeat($._top_level),
    ),

    _top_level: $ => choice(
      $.enum_decl,
      $.trait_decl,
      $.trait_impl,
      $.struct_decl,
      $.const_decl,
      $.ffi_block,
      $.process_block,
      $.newtype_decl,
    ),


    // =========================================================
    // Comments: ;; to end of line
    // =========================================================

    comment: $ => token(seq(';;', /.*/)),


    // =========================================================
    // Atomic identifiers
    // =========================================================

    // PascalCase — types, domains, variants, modules, fields
    _upper_ident: $ => /[A-Z][a-zA-Z0-9]*/,

    // camelCase — traits, methods
    _lower_ident: $ => /[a-z][a-zA-Z0-9]*/,

    type_identifier: $ => $._upper_ident,
    identifier: $ => $._lower_ident,


    // =========================================================
    // Literals
    // =========================================================

    float_literal: $ => /[0-9]+\.[0-9]+/,
    integer_literal: $ => /[0-9]+/,

    string_literal: $ => seq(
      '"',
      repeat(choice(
        $.string_content,
        $.string_escape,
      )),
      '"',
    ),

    string_content: $ => token.immediate(prec(-1, /[^"\\]+/)),
    string_escape: $ => token.immediate(/\\[nrt\\\"0]/),


    // =========================================================
    // References and sigils
    // =========================================================

    // @Name — instance declaration/reference
    instance_ref: $ => seq('@', $._upper_ident),

    // @Self
    self_ref: $ => '@Self',

    // :@Self or :@Name — borrow
    borrow_ref: $ => seq(':', choice($.self_ref, $.instance_ref)),

    // ~@Self or ~@Name — mutable
    mutable_ref: $ => seq('~', choice($.self_ref, $.instance_ref)),

    // $Name or $Name&Bound — generic type parameter
    generic_param: $ => seq(
      '$',
      $._upper_ident,
      repeat(seq('&', $._upper_ident)),
    ),

    // Type/Variant, Type/Variant(args), Type/method(args) — path expression
    path_expr: $ => prec.left(PREC.PATH, seq(
      $.type_identifier,
      '/',
      choice(
        // Type/method(args) — camelCase method
        seq($.identifier, token.immediate('('), optional($._call_args), ')'),
        // Type/Variant(args) — PascalCase constructor with args
        seq($.type_identifier, token.immediate('('), optional($._call_args), ')'),
        // Type/Variant — bare variant
        $.type_identifier,
      ),
    )),


    // =========================================================
    // Type expressions
    // =========================================================

    _type: $ => choice(
      $.type_application,
      $.generic_param,
      $.type_identifier,
    ),

    // [Vec Element], [Option $Value], [Vec [Option $Value]]
    type_application: $ => seq(
      '[',
      field('constructor', $.type_identifier),
      repeat1($._type),
      ']',
    ),


    // =========================================================
    // MODULE: (Name Export1 Export2 [Mod Import1 Import2])
    // First () at root is always the module declaration
    // =========================================================

    module_decl: $ => seq(
      '(',
      field('name', $.type_identifier),
      repeat($.module_export),
      repeat($.module_import),
      ')',
    ),

    // Export: PascalCase type or camelCase trait
    module_export: $ => choice($.type_identifier, $.identifier),

    // [ModuleName Import1 Import2]
    module_import: $ => seq(
      '[',
      $.type_identifier,
      repeat(choice($.type_identifier, $.identifier)),
      ']',
    ),


    // =========================================================
    // ENUM: (Name Variant1 (Variant2 Type) ...)
    // The () form of domain. One-of.
    // =========================================================

    enum_decl: $ => prec.dynamic(1, seq(
      '(',
      field('name', $.type_identifier),
      repeat1($._enum_member),
      ')',
    )),

    _enum_member: $ => choice(
      $.data_variant,
      $.struct_variant,
      $.nested_enum,
      $.nested_struct,
      $.bare_variant,
    ),

    // Bare variant: just a PascalCase name
    bare_variant: $ => prec.dynamic(-1, $.type_identifier),

    // Data-carrying variant: (Variant Type) or (Variant [Vec Type]) or (Variant $Param)
    data_variant: $ => seq(
      '(',
      field('name', $.type_identifier),
      $._type,
      ')',
    ),

    // Struct-form variant: {Variant (Field Type) ...}
    struct_variant: $ => seq(
      '{',
      field('name', $.type_identifier),
      repeat1($._struct_member),
      '}',
    ),

    // Nested enum inside enum/struct: (| InnerEnum A B C |)
    nested_enum: $ => seq(
      '(|',
      field('name', $.type_identifier),
      repeat1($._enum_member),
      '|)',
    ),

    // Nested struct inside enum/struct: {| InnerStruct (Field Type) |}
    nested_struct: $ => seq(
      '{|',
      field('name', $.type_identifier),
      repeat1($._struct_member),
      '|}',
    ),


    // =========================================================
    // STRUCT: {Name (Field Type) BareField ...}
    // The {} form of domain. All-of.
    // =========================================================

    struct_decl: $ => seq(
      '{',
      field('name', $.type_identifier),
      repeat1($._struct_member),
      '}',
    ),

    _struct_member: $ => choice(
      $.typed_field,
      $.self_typed_field,
      $.nested_enum,
      $.nested_struct,
    ),

    // (FieldName Type) or (FieldName [Vec Type])
    typed_field: $ => seq(
      '(',
      field('name', $.type_identifier),
      $._type,
      ')',
    ),

    // FieldName — self-typed (field name IS the type)
    self_typed_field: $ => $.type_identifier,


    // =========================================================
    // NEWTYPE: Name Type (bare, undelimited)
    // =========================================================

    newtype_decl: $ => prec.dynamic(-2, seq(
      field('name', $.type_identifier),
      field('type', $._type),
    )),


    // =========================================================
    // CONSTANTS: {| Name Type Value |}
    // =========================================================

    const_decl: $ => seq(
      '{|',
      field('name', $.type_identifier),
      field('type', $._type),
      field('value', $._literal),
      '|}',
    ),

    _literal: $ => choice(
      $.float_literal,
      $.integer_literal,
      $.string_literal,
    ),


    // =========================================================
    // TRAIT DECLARATION: (traitName [(sig1) (sig2)])
    // =========================================================

    trait_decl: $ => prec.dynamic(2, seq(
      '(',
      field('name', $.identifier),
      '[',
      repeat1($.signature),
      ']',
      ')',
    )),

    // (methodName :@Self Type) or (methodName :@Self @Param Type ReturnType)
    signature: $ => seq(
      '(',
      field('name', $.identifier),
      repeat1($.sig_param),
      optional(field('return_type', $._type)),
      ')',
    ),

    sig_param: $ => choice(
      $.borrow_ref,
      $.mutable_ref,
      seq($.instance_ref, $._type),
      seq($.instance_ref, $.type_application),
      $.instance_ref,
    ),


    // =========================================================
    // TRAIT IMPLEMENTATION: [traitName Type [methods]]
    // =========================================================

    trait_impl: $ => prec.dynamic(1, seq(
      '[',
      field('trait_name', $.identifier),
      field('for_type', $.type_identifier),
      '[',
      repeat1($.method_def),
      ']',
      ']',
    )),

    // (methodName params Type body)
    method_def: $ => seq(
      '(',
      field('name', $.identifier),
      repeat($.param),
      optional(field('return_type', $._type)),
      $._method_body,
      ')',
    ),

    param: $ => choice(
      $.borrow_ref,
      $.mutable_ref,
      seq($.instance_ref, $._type),
      $.instance_ref,
    ),

    _method_body: $ => choice(
      $.block_body,
      $.match_body,
      $.iteration_body,
    ),

    // [...] — block with statements and tail expression
    block_body: $ => seq('[', repeat($._statement), ']'),

    // (| arms |) — pattern matching
    match_body: $ => seq(
      '(|',
      repeat1($.match_arm),
      '|)',
    ),

    match_arm: $ => prec.dynamic(1, seq(
      '(',
      $._pattern,
      ')',
      $._expr,
    )),

    _pattern: $ => choice(
      $.or_pattern,
      $.destructure_pattern,
      $.variant_pattern,
      $.string_literal,
    ),

    // (Fire | Air)
    or_pattern: $ => seq(
      $.type_identifier,
      repeat1(seq('|', $.type_identifier)),
    ),

    // (Ident @Name) — data destructuring
    destructure_pattern: $ => seq(
      $.type_identifier,
      $.instance_ref,
    ),

    // (Fire) or (Newline) — simple variant
    variant_pattern: $ => $.type_identifier,

    // [| body |] — iteration body
    iteration_body: $ => seq('[|', repeat($._statement), '|]'),


    // =========================================================
    // STATEMENTS (inside block bodies)
    // =========================================================

    _statement: $ => choice(
      $.instance_stmt,
      $.mutation_stmt,
      $.loop_stmt,
      $.iteration_stmt,
      $.match_expr,
      $.stdout_stmt,
      $.stderr_stmt,
      $._expr,
    ),

    // ^expr — early return
    early_return: $ => prec.right(PREC.RETURN, seq('^', $._expr)),

    // @Name Type/Constructor(args) — instance declaration
    instance_stmt: $ => prec.dynamic(3, seq(
      $.instance_ref,
      $._expr,
    )),

    // ~@Name Type/Constructor(args) — mutable instance
    // ~@Name.method [body] — mutable method call
    mutation_stmt: $ => prec.dynamic(3, seq(
      $.mutable_ref,
      $._expr,
    )),

    // [| condition body |] — loop
    loop_stmt: $ => seq(
      '[|',
      $._expr,
      repeat1($._statement),
      '|]',
    ),

    // {| source [body] |} — iteration
    iteration_stmt: $ => seq(
      '{|',
      $._expr,
      $.block_body,
      '|}',
    ),

    // (| expr arms |) — inline match
    match_expr: $ => seq(
      '(|',
      optional($._expr),
      repeat1($.match_arm),
      '|)',
    ),

    // StdOut expr
    stdout_stmt: $ => seq('StdOut', $._expr),

    // StdErr expr
    stderr_stmt: $ => seq('StdErr', $._expr),


    // =========================================================
    // EXPRESSIONS
    // =========================================================

    _expr: $ => choice(
      $._primary_expr,
      $.binary_expr,
      $.field_access,
      $.method_call,
      $.try_expr,
      $.path_expr,
      $.early_return,
    ),

    _primary_expr: $ => choice(
      $.instance_ref,
      $.self_ref,
      $.borrow_ref,
      $.mutable_ref,
      $.generic_param,
      $.float_literal,
      $.integer_literal,
      $.string_literal,
      $.type_identifier,
      $.identifier,
      $.block_expr,
    ),

    // [expr] — inline eval / block expression
    block_expr: $ => seq('[', repeat1($._statement), ']'),

    // Binary operators
    binary_expr: $ => choice(
      prec.left(PREC.MULTIPLY, seq($._expr, choice('*', '%'), $._expr)),
      prec.left(PREC.ADD, seq($._expr, choice('+', '-'), $._expr)),
      prec.left(PREC.COMPARE, seq($._expr, choice('==', '!=', '<=', '>=', '<', '>'), $._expr)),
      prec.left(PREC.LOGICAL_AND, seq($._expr, '&&', $._expr)),
      prec.left(PREC.LOGICAL_OR, seq($._expr, '||', $._expr)),
    ),

    // expr.Field — field access
    field_access: $ => prec.left(PREC.ACCESS, seq(
      $._expr,
      token.immediate('.'),
      choice($._upper_ident, $._lower_ident),
    )),

    // expr.method(args) — method call
    method_call: $ => prec.left(PREC.CALL, seq(
      $._expr,
      token.immediate('.'),
      $._lower_ident,
      choice(
        seq(token.immediate('('), optional($._call_args), ')'),
        $.block_body,
      ),
    )),

    _call_args: $ => repeat1($._expr),

    // expr? — try/unwrap
    try_expr: $ => prec(PREC.POSTFIX, seq(
      $._expr,
      token.immediate('?'),
    )),


    // =========================================================
    // FFI: (| Name (func @Param Type RetType) |)
    // =========================================================

    ffi_block: $ => seq(
      '(|',
      field('name', $.type_identifier),
      repeat1($.ffi_function),
      '|)',
    ),

    ffi_function: $ => seq(
      '(',
      field('name', $.identifier),
      repeat($.ffi_param),
      field('return_type', $._type),
      ')',
    ),

    ffi_param: $ => seq(
      $.instance_ref,
      $._type,
    ),


    // =========================================================
    // PROCESS: [| statements |]
    // =========================================================

    process_block: $ => seq(
      '[|',
      repeat1($._statement),
      '|]',
    ),
  },
});
