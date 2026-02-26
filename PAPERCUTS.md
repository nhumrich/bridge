# Pact Papercuts & Issues

Tracking every issue encountered while building Bridge, for feeding back to Pact development.

## 1. `process_run()` signature mismatch in docs
- **Docs say**: `process_run(cmd)` takes one string arg containing the full command
- **Reality**: `process_run(cmd, args)` takes a program name + a `List[Str]` of arguments. Under the hood it uses `execvp()`, NOT a shell — so shell features (pipes, redirects) don't work.
- **Impact**: Every call to `process_run("some command with args")` fails at C compilation. All LLM docs examples are wrong.
- **Workaround**: Use `process_run("program", ["arg1", "arg2"])` or `process_run("sh", ["-c", "shell command"])` for shell features. `shell_exec(cmd)` works for fire-and-forget shell commands but only returns exit code.
- **Severity**: Blocker — fundamental API used constantly. Docs actively misleading.

## 2. `std.args` module not found
- **Docs say**: `import std.args` imports the stdlib arg parser
- **Reality**: Resolves to `src/std/args.pact` (relative to project), not a stdlib path. Module not found.
- **Impact**: Can't use the built-in CLI argument parser at all
- **Workaround**: Hand-roll arg parsing with `arg_count()` / `get_arg(idx)`
- **Severity**: Blocker — stdlib imports appear broken or require undocumented config

## 3. Lexer crash on unescaped `{` in strings
- **Issue**: Every `{` inside a double-quoted string triggers interpolation — even `"},{"`
- **Symptom**: `pact: list index out of bounds: idx=N len=N` + `lexer error: unexpected character`
- **The crash is a compiler bug** — it should emit a clear "unclosed interpolation" error, not an index-out-of-bounds panic
- **Workaround**: Escape ALL literal braces: `"\},\{"` instead of `"},{"`
- **Severity**: Medium — easy to work around once you know, but the crash message is cryptic and misleading. Also annoying when working with JSON strings.

## 4. `List[T].is_empty()` fails at build time
- **Issue**: `.is_empty()` on `List[Str]` typechecks OK but fails at build with `unresolved method '.is_empty'`
- **Affects**: ALL `List[T]` variables, not just collected iterators. Also `.starts_with()` etc on collected lists.
- **Root cause**: `pact check` accepts it, but `pact build` (C codegen) doesn't resolve the method
- **Workaround**: Use `.len() == 0` instead of `.is_empty()` for lists
- **Severity**: High — very common pattern, inconsistency between check and build is confusing

## 5. `pact run` doesn't support `--` for passing args
- **Issue**: `pact run src/main.pact -- arg1 arg2` fails with `error: unknown option '--'`
- **Impact**: Can't test CLI apps that take args via `pact run`. Must `pact build` first, then run the binary.
- **Workaround**: Build first, then run the binary directly
- **Severity**: Low-medium — annoying for development workflow

## 6. C reserved words as parameter names
- **Issue**: Using C reserved words like `short` as Pact parameter names compiles to invalid C
- **Symptom**: `error: expected ';', ',' or ')' before 'short'`
- **Workaround**: Avoid C reserved words in parameter names (short, long, int, float, double, char, void, etc.)
- **Severity**: Medium — Pact should mangle these names during C codegen

## 7. Closure codegen issues with `.any()` on List
- **Issue**: `list.any(fn(a) \{ a == captured_var \})` generates invalid C with `void` parameter types
- **Symptom**: `error: 'void' must be the only parameter and unnamed`
- **Workaround**: Avoid closures that capture variables in `.any()`, `.filter()` etc. Use manual loops instead.
- **Severity**: High — closures with captures are fundamental to functional list operations

## 8. `if/else` as implicit return produces null (CRITICAL)
- **Issue**: Using `if/else` as the last expression in a function body (implicit return) generates C code that doesn't actually return the value — the expression result is discarded
- **Symptom**: Function returns `(null)` at runtime, segfault if the caller dereferences it
- **Example**: `fn foo(x: Str) -> Str \{ if x.len() > 3 \{ x.slice(0,3) \} else \{ x \} \}` returns null
- **Workaround**: Use explicit `return` in the `if` branch, and let the else value fall through: `if cond \{ return val1 \} val2`
- **Severity**: CRITICAL — this is a fundamental language feature. The docs say "last expression is return value" but it doesn't work for if/else.

## 10. `%` in interpolated strings consumed by snprintf
- **Issue**: `"LIKE '{val}%'"` produces `LIKE 'hello` — the `%'` is eaten by C's snprintf as a format specifier
- **Root cause**: Pact uses snprintf for string interpolation but doesn't escape `%` → `%%` in literal parts
- **Workaround**: Use `%%` for literal `%` in any string that contains `{interpolation}`: `"LIKE '{val}%%'"`
- **Severity**: High — silent data corruption / format string vulnerability in generated C code

## 9. `if/else` expression type inference fails with `.to_int()`
- **Issue**: `let p = if s.is_empty() \{ -1 \} else \{ s.to_int() \}` generates `const void p = 0`
- **Root cause**: Codegen can't unify the literal `-1` with the method return type of `.to_int()`
- **Explicit type annotation `let p: Int = ...` doesn't help**
- **Workaround**: Use mutable variable: `let mut p = -1` then `if !s.is_empty() \{ p = s.to_int() \}`
- **Severity**: Medium — common pattern, easy workaround

## 9. `List.pop() ?? default` codegen broken
- **Issue**: `stack.pop() ?? ""` generates invalid C — `pact_Option_str` initialized to `0`
- **Workaround**: `stack.get(stack.len() - 1)` then `stack.pop()` (ignore return)
- **Severity**: Medium — `??` operator not working with `Option` return from `pop()`

## 11. `List.get()` returns `Option[T]` in v0.6 (BREAKING)
- **Change**: `List.get(idx)` now returns `Option[T]` instead of `T`
- **Impact**: ~30+ call sites need `?? default_value` suffix
- **Status**: Documented breaking change, all call sites updated
- **Severity**: High — silent breakage, no compile error without `??`

## v0.6 Status Update
- Issues 1-10 are **confirmed still present** in Pact v0.6
- `process_run()` docs now claim single-string signature, but **reality unchanged** — still requires 2 args (program + args list)
- New `const` keyword available for module-level constants
- `List.get()` → `Option[T]` is the only breaking change encountered
