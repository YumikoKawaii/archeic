# archeic

Media and storage player. `server/` is Go + MySQL + RustFS (S3-compatible), `presentation/` is React + Vite + TypeScript. No authentication.

# Coding rules

## General

- No comments in code.
- No test files (`_test.go`, `*.test.ts`, `*.spec.ts`) anywhere in this project.
- Keep changes minimal and scoped to the request.
- Match the existing naming, structure, and idiom of surrounding code.

## Go

### Layout

- Entrypoints live in `server/cmd/<name>/main.go`; `main` only wires dependencies and starts the server.
- Application code lives in `server/internal/<package>`. Packages are small, single-purpose, and named by what they provide (`model`, `repository`, `storage`, `api`), never `util`, `common`, or `helpers`.
- No import cycles; dependencies flow `api -> repository/storage -> model/config`.
- `model` holds domain types and pure domain behaviour (e.g. `Items.Move`); no I/O.

### Style

- Code must pass `gofmt`, `go vet`, and `staticcheck`.
- Short, lowercase package names; no stutter (`model.Media`, not `model.MediaModel`).
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
- Services follow `<Resource>Service` naming with `Get`, `List`, `Create`, `Update`, `Delete` RPCs; request/response messages are `<Service><Rpc>Request` / `<Service><Rpc>Response` (e.g. `MediaServiceListRequest`) so `buf lint` passes with several services in one package.
- Handlers implement the generated `<Service>Handler` interface, convert proto messages to domain types at the boundary, and never leak proto types into `model`, `repository` or `storage`.
- Return errors with `connect.NewError(connect.Code..., err)`; map `repository.ErrNotFound` to `connect.CodeNotFound`, validation failures to `connect.CodeInvalidArgument`.
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
- Map `sql.ErrNoRows` to `repository.ErrNotFound` at the repository boundary.

### Unit of work

- All database access goes through `repository.UnitOfWork`; it exposes one accessor per repository (`uow.Media()`, `uow.Collection()`, ...).
- Repositories take a `DBTX` and are simple: one table, plain CRUD and single-statement queries. No business rules, no cross-repository calls, no transactions inside a repository.
- Any operation with more than one statement, or a read that decides a write, runs inside `uow.Tx(ctx, func(tx *repository.UnitOfWork) error { ... })` and uses only `tx` repositories inside the closure.
- Use `LockX` methods (`SELECT ... FOR UPDATE`) inside `Tx` when a read decides a write.
- Business rules (validation, ordering, hierarchy checks) live in the caller (`api`) or in `model`, not in repositories.
- Side effects outside MySQL (object storage) run last inside the `Tx` closure so a failure rolls the database back.
- Schema changes are SQL files in `server/migrations/`, run with golang-migrate: `NNNNNN_<description>.up.sql` plus a matching `.down.sql`, one change per file, never edit an applied migration.
- Apply with `archeic migrate up` (roll back with `archeic migrate down`); the server never migrates on start.

### Storage

- All object access goes through `internal/storage`; handlers never import the S3 SDK (`minio-go`, used as a generic S3 client with path-style addressing). Object storage is RustFS `rustfs/rustfs`, pinned to an exact release tag; config lives under `S3_*` env vars.
- Object keys are `<kind>/<uuid><ext>`.
- If a DB write fails after an upload, remove the object.

### Config

- Config comes from environment variables only, loaded once in `config.Load()`. Non-secret settings may have local-dev defaults; credentials and DSNs never have defaults in code.
- No globals beyond constants and sentinel errors.

### Dependencies

- Prefer the standard library. Add a module only when it removes real complexity.
- Run `go mod tidy` after changing imports.

## Presentation

- Visual style is Gallery minimal, dark: near-black background, media edge to edge in justified rows with 3px gaps, almost no chrome, names only on hover, one light-blue accent for primary actions, Figtree type. Colors come from the tokens in `src/styles.css`; no new literal colors.
- Function components with hooks; strict TypeScript, no `any`.
- All API calls go through `src/api/client.ts` using the generated Connect-ES client (`@connectrpc/connect-web`).
- Source layout under `presentation/src/`:
  - `main.tsx`, `App.tsx`: entry and top-level shell only.
  - `api/`: the API client. `gen/`: generated code, never edited.
  - `layout/`: app chrome (sidebar, header pieces).
  - `features/<area>/`: one folder per area (`library`, `category`, `collection`, `media`) holding its views and the components only it uses.
  - `components/`: small components shared by more than one feature.
  - `lib/`: non-UI helpers and shared types.
  - `styles/`: global CSS.
- Never put new files directly in `src/`; place them in the folder that matches their role.
- Media is loaded from `/api/media/{id}/content`; never point the browser directly at object storage.

## Git

- One commit per noticeable change: a single feature, fix, or refactor that can be reviewed and measured on its own.
- Never mix unrelated changes in one commit; split large work into a sequence of small, self-contained commits.
- Each commit builds on its own.
- Generated code goes in the same commit as the proto change that produced it.
- Message: one line, `{change}: message`, at most 40 characters, no body.

## Running

- Copy `.env.example` to `.env` and fill in credentials; `.env` is git-ignored and `docker-compose.yml` reads every secret from it. Never commit real credentials.
- `docker compose up -d --build` in `archeic/`; the `migrate` service runs `migrate up` before `server` starts. App on `http://localhost:8080`, RustFS console on `http://localhost:9001`.
