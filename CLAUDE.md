# archeic

Media and storage player. `server/` is Go + MySQL + MinIO, `presentation/` is React + Vite + TypeScript. No authentication.

# Coding rules

## General

- No comments in code.
- No test files (`_test.go`, `*.test.ts`, `*.spec.ts`) anywhere in this project.
- Keep changes minimal and scoped to the request.
- Match the existing naming, structure, and idiom of surrounding code.

## Go

### Layout

- Entrypoints live in `server/cmd/<name>/main.go`; `main` only wires dependencies and starts the server.
- Application code lives in `server/internal/<package>`. Packages are small, single-purpose, and named by what they provide (`store`, `storage`, `api`), never `util`, `common`, or `helpers`.
- No import cycles; dependencies flow `api -> store/storage -> config`.

### Style

- Code must pass `gofmt`, `go vet`, and `staticcheck`.
- Short, lowercase package names; no stutter (`store.Store`, not `store.MediaStore` when unambiguous).
- Exported identifiers only when used outside the package.
- Receiver names are short and consistent per type.
- Accept interfaces, return concrete types. Define interfaces at the consumer, not the producer.
- Prefer early returns over nested `else`.

### Errors

- Always handle errors; never discard with `_` except for best-effort cleanup.
- Wrap with context using `fmt.Errorf("doing x: %w", err)`.
- Use sentinel errors (`var ErrNotFound = errors.New(...)`) and check with `errors.Is` / `errors.As`.
- No `panic` outside of `main` startup.
- Do not log and return the same error; do one.

### Context and concurrency

- `context.Context` is the first parameter of any function doing I/O; never store it in a struct.
- Use the request context (`r.Context()`) in handlers.
- Every goroutine must have a clear owner and exit path; no fire-and-forget.
- Protect shared state with a mutex or channels.

### Version

- Go 1.26 (latest). Use modern language and stdlib features: generics, range-over-func iterators, `for range n`, `min`/`max`/`clear`, `slices`, `maps`, `iter`, `log/slog`, `errors.Join`.
- `go.mod` declares `go 1.26`; Docker images use `golang:1.26`.

### RPC

- API is Connect RPC (`connectrpc.com/connect`) with protobuf definitions in `server/proto/archeic/v1/*.proto`.
- Code generation with `buf` (`buf.yaml`, `buf.gen.yaml`); generated code lives in `server/gen/` and is never edited by hand.
- Services follow `<Resource>Service` naming with `Get`, `List`, `Create`, `Update`, `Delete` RPCs; request/response messages are `<Rpc>Request` / `<Rpc>Response`.
- Handlers implement the generated `<Service>Handler` interface, convert proto messages to domain types at the boundary, and never leak proto types into `store` or `storage`.
- Return errors with `connect.NewError(connect.Code..., err)`; map `store.ErrNotFound` to `connect.CodeNotFound`, validation failures to `connect.CodeInvalidArgument`.
- Use interceptors (`connect.WithInterceptors`) for cross-cutting concerns (logging, recovery, validation), not per-handler code.
- Serve over `net/http` with `http.Protocols` enabling HTTP/1.1 and unencrypted HTTP/2 so Connect, gRPC, and gRPC-Web all work.
- Binary media upload and streaming stay on plain `net/http` routes alongside Connect: upload via multipart, playback via `http.ServeContent` so Range requests work.

### Go idioms

- Make the zero value useful; avoid constructors when a zero value works.
- Small interfaces (one or two methods), named with `-er` when natural (`Reader`, `Storer`).
- Accept interfaces, return structs.
- Errors are values: return them, don't panic; check immediately after the call.
- Use `defer` for cleanup right after acquiring a resource.
- Don't communicate by sharing memory; share memory by communicating, but use a mutex when it is simpler.
- Clear is better than clever; prefer a little copying over a little dependency.
- Avoid getters named `GetX`; use `X()`. Setters are `SetX()`.
- Use `any` only at true boundaries; prefer generics with constraints.
- Use functional options (`func(*T)`) for optional configuration, not config structs with many zero fields.
- Return early, keep the happy path left-aligned.
- Name by meaning, scope length matches name length (`i` in a loop, `mediaStore` across a package).

### OOP in Go

- No classes or inheritance; model with structs plus methods.
- Composition over inheritance: embed types to reuse behaviour, and only embed when promoting the full method set is intended.
- Polymorphism through implicit interfaces; never declare `implements`. Assert compile-time conformance with `var _ Iface = (*T)(nil)`.
- Encapsulation through package boundaries and unexported fields, not getters/setters on every field.
- Pointer receivers when the method mutates state or the struct is large; keep receiver kind consistent across all methods of a type.
- Constructors are `NewT(...) *T` only when invariants must be established.
- Dependencies are injected via struct fields or constructor args typed as interfaces; no global singletons.
- Prefer behaviour (methods) on domain types over anemic structs plus free functions when the logic belongs to the type.

### Database

- `database/sql` with the MySQL driver; parameterized queries only, never string-concatenated values.
- Always `defer rows.Close()` and check `rows.Err()`.
- Map `sql.ErrNoRows` to `store.ErrNotFound` at the store boundary.
- Schema changes go through `Migrate`, idempotent (`IF NOT EXISTS`).

### Storage

- All object access goes through `internal/storage`; handlers never import the MinIO SDK.
- Object keys are `<kind>/<uuid><ext>`.
- If a DB write fails after an upload, remove the object.

### Config

- Config comes from environment variables only, loaded once in `config.Load()`, with defaults for local dev.
- No globals beyond constants and sentinel errors.

### Dependencies

- Prefer the standard library. Add a module only when it removes real complexity.
- Run `go mod tidy` after changing imports.

## Presentation

- Function components with hooks; strict TypeScript, no `any`.
- All API calls go through `src/api.ts` using the generated Connect-ES client (`@connectrpc/connect-web`).
- Media is loaded from `/api/media/{id}/content`; never point the browser directly at MinIO.

## Git

- One commit per noticeable change: a single feature, fix, or refactor that can be reviewed and measured on its own.
- Never mix unrelated changes in one commit; split large work into a sequence of small, self-contained commits.
- Each commit builds on its own.
- Generated code goes in the same commit as the proto change that produced it.
- Message: one line, `{change}: message`, at most 40 characters, no body.

## Running

- `docker compose up -d --build` in `archeic/`. App on `http://localhost:8080`, MinIO console on `http://localhost:9001`.
