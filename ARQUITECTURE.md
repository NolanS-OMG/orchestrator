# Architecture

## blue-web (Frontend)

Stack: React + TypeScript + Vite

### src/ structure

```
src/
  api.ts                        # ApiClient class — centralized HTTP client (GET, POST, PUT, PATCH, DELETE)
  router/
    index.tsx                   # AppRouter — RootRedirect, PublicRoute, PrivateRoute, NotFound catch-all
    PrivateRoute.tsx             # Redirects to /login if not authenticated
    PublicRoute.tsx              # Redirects to /dashboard if already authenticated
  auth/
    tokenService.ts             # Single source of truth for auth token (localStorage)
  hooks/
    useStateApi.ts              # Generic hook for managing API call state (loading, data, error, abort)
  components/
    <ComponentName>/
      <ComponentName>.tsx
      styles/        # CSS Modules
      hooks/         # Component-scoped hooks (follow useStateApi pattern)
      data/          # Component-scoped static data (*.data.ts)
    Layout/          # Wrapper for all private routes: sidebar nav (logo, nav links, logout) + <Outlet />
    InitSession/     # Auth form (sign in / sign up tabs)
    Dashboard/       # Main page after login: greeting (email from localStorage) + summary cards
    CreateTenant/    # Tenant creation form (name, slug, settings)
    TenantDetail/    # Tenant detail + inline settings editor (goal, reward, cooldown_hours)
    Staff/           # Staff management
      StaffList.tsx         # Staff list for a tenant (loading, error, empty + list states)
      styles/
        StaffList.module.css
      hooks/
        useGetStaff.ts      # GET /api/staff?tenant_id=...
        useCreateStaff.ts   # POST /api/staff
        useStaffLogin.ts    # POST /api/staff/login
    StaffLogin/      # Public Staff App entry — PIN login screen
      StaffLogin.tsx        # PIN login form; staff selector dropdown if list available; tenant_id from ?tenant_id= query param
      styles/
        StaffLogin.module.css
    NotFound/        # 404 page shown for unmatched routes
  data/
    translation/
      es.json        # All UI strings in Spanish (only supported language)
  App.tsx            # Renders AppRouter
  main.tsx           # Entry point — wraps App in BrowserRouter + initializes i18n
  index.css          # Global CSS variables: colors, typography scale, spacing scale, border radius, sidebar tokens, status colors, breakpoints
```

### Route tree

```
/                         → RootRedirect (→ /dashboard if authenticated, else /login)
/login                    → InitSession (PublicRoute)
/register                 → InitSession (PublicRoute, same component)
/dashboard                → Dashboard (PrivateRoute > Layout)
/tenants/new              → CreateTenant (PrivateRoute > Layout)
/tenants/:tenantId        → TenantDetailPage > TenantDetail (PrivateRoute > Layout)
/tenants/:tenantId/staff  → StaffListPage > StaffList (PrivateRoute > Layout)
/staff/login              → StaffLogin (standalone public — no auth redirect)
*                         → NotFound
```

`TenantDetailPage` is an inline wrapper in `router/index.tsx` that reads `useParams` and guards against missing `tenantId` before rendering `<TenantDetail tenantId={...} />`.

### Components

#### Layout
Sidebar navigation shell for all private routes. Renders a fixed sidebar with: logo ("Blueprint"), nav links from `NAV_LINKS` (data file), and a logout button that calls `removeToken()` then navigates to `/login`. Uses `<Outlet />` for the page content area.

#### InitSession
Tab-based auth form that handles both sign-in and sign-up in a single component (`sign_in` | `sign_up` tabs). On success, saves token and email to localStorage then navigates to `/dashboard`. Validates password confirmation for sign-up client-side before calling the API.

Hooks used:
- `useLogin` — POST `/api/auth/login`
- `useRegister` — POST `/api/auth/register`

#### Dashboard
Landing page after login. Shows a greeting with the user's email (read from localStorage via `getUserEmail`) and two static summary cards ("Mis Negocios", "Mi Staff") rendered from `SUMMARY_CARDS` in `Dashboard.data.ts`. Both cards currently display an empty state placeholder — no API calls are made from this component.

#### CreateTenant
Form to create a new tenant with: name, auto-generated slug (derived from name, can be overridden manually), and settings (goal, reward, cooldown_hours). Default values for goal and cooldown_hours come from `CreateTenant.data.ts`. On success navigates to `/tenants/:id`.

Hooks used:
- `useCreateTenant` — POST `/api/tenants`

#### TenantDetail
Displays tenant info (name, slug) and an editable settings form. Manages a local `draft` state keyed by `tenantId` to track unsaved changes without mutating the server state. Shows loading/error states from the GET call, and save/error feedback from the PUT call.

Hooks used:
- `useGetTenant` — GET `/api/tenants/:id`
- `useUpdateTenant` — PUT `/api/tenants/:id`

### CSS Design System (index.css)

All design tokens are defined as CSS custom properties in `:root` and consumed via `var()` throughout component CSS Modules. No hardcoded color, spacing, or radius values should appear in component styles.

Token groups:
- **Colors**: `--text`, `--text-h`, `--bg`, `--border`, `--accent`, `--accent-bg`, `--page-bg`
- **Status**: `--success`, `--warning`, `--danger` (each with a `-bg` variant)
- **Sidebar** (always dark, independent of color scheme): `--sidebar-bg`, `--sidebar-width`, `--sidebar-text`, `--sidebar-text-active`, `--sidebar-hover-bg`, `--sidebar-active-bg`, `--sidebar-divider`
- **Typography sizes**: `--text-xs` → `--text-3xl`
- **Font weights**: `--font-normal`, `--font-medium`, `--font-semibold`, `--font-bold`
- **Spacing**: `--sp-1` → `--sp-12`
- **Border radius**: `--radius-sm`, `--radius-md`, `--radius-lg`, `--radius-xl`
- **Shadows**: `--shadow`, `--shadow-md`
- **Breakpoints**: `--xs-screen` → `--xl-screen`

### api.ts

`ApiClient` is the single entry point for all HTTP calls. It wraps the native `fetch` API and exposes typed methods. Base URL is read from `VITE_API_URL` env var at module load time.

- Automatically attaches `Authorization: Bearer <token>` header when `isAuthenticated()` returns true.
- Throws an `Error` with the HTTP status and status text for non-2xx responses.
- Each component hook creates its own `ApiClient` instance (module-level constant inside the hook file).

Usage:
```ts
import { ApiClient } from '../api';

const api = new ApiClient();
const data = await api.get<MyType>('/endpoint');
```

### auth/tokenService.ts

Single source of truth for authentication state. All values are persisted in `localStorage`.

Exported functions:
- `saveToken(token, { expiresAt? })` — stores token and optional expiry (accepts seconds, milliseconds, or ISO date string)
- `getToken()` — returns raw token string or null
- `removeToken()` — removes token and expiry from localStorage
- `getTokenExpiration()` — returns expiry as ms timestamp or null
- `isAuthenticated()` — returns true if token exists and has not expired; auto-removes expired tokens
- `saveUserEmail(email)` — persists user email for display (e.g. Dashboard greeting)
- `getUserEmail()` — returns stored email or null

### hooks/useStateApi.ts

Generic hook that wraps any async API function and manages its lifecycle state. All component-scoped hooks in this project are built on top of this hook.

```ts
const { data, loading, error, call, setData, reset, abort } = useStateApi({
  apiFunction,   // (...args) => Promise<T>
  onSuccess?,    // (data: T) => void
  onError?,      // (error: Error) => void
  onFinally?,    // () => void
});
```

Key behaviors:
- Uses `AbortController` internally; aborts any in-flight request before starting a new one.
- Auto-aborts on component unmount (via `useEffect` cleanup).
- `reset()` restores state to initial (`data: null, loading: false, error: null`) and aborts any pending request.
- `setData()` allows external state patches without triggering a new API call.

### i18n

Initialized in `main.tsx` using `react-i18next`. Spanish (`es`) is the only language and the fallback. All translation strings live in `src/data/translation/es.json`. Components access strings via `const { t } = useTranslation()` and reference keys like `components.<componentName>.<key>`.

### Data files pattern

Static values that would otherwise be hardcoded inside components are extracted to `*.data.ts` files co-located with their component:

| File | Exports |
|------|---------|
| `Layout/data/Layout.data.ts` | `NAV_LINKS` — sidebar nav items (labelKey + path) |
| `Dashboard/data/Dashboard.data.ts` | `SUMMARY_CARDS` — summary card label keys for the dashboard |
| `CreateTenant/data/CreateTenant.data.ts` | `DEFAULT_GOAL`, `DEFAULT_COOLDOWN_HOURS` — form defaults |

### Component hooks pattern

Each component-scoped hook follows this structure:
1. Define the API path as a constant.
2. Define request/response TypeScript interfaces.
3. Create a module-level `ApiClient` instance.
4. Define a typed request function (e.g. `loginRequest`).
5. Export a hook that calls `useStateApi` with the request function and forwards `onSuccess`/`onError` options.

Example:
```ts
const apiClient = new ApiClient();
const loginRequest = (creds: LoginCredentials): Promise<LoginResponse> =>
  apiClient.post<LoginResponse>(LOGIN_PATH, creds);

export const useLogin = (options: UseLoginOptions = {}) =>
  useStateApi<LoginResponse, [LoginCredentials]>({ apiFunction: loginRequest, ...options });
```

---

## blue-api (Backend)

Stack: Node.js + TypeScript + Express + PostgreSQL

### src/ structure

```
src/
  index.ts                        # Entry point — mounts global middlewares and starts the server
  config/
    env.ts                        # Loads, validates, and types all environment variables
  db/
    client.ts                     # PostgreSQL Pool + verifyDatabaseConnection helper
    migrate.ts                    # SQL migration runner (npm run migrate)
    createDatabase.ts             # Utility: creates the DB if it doesn't exist
    dropDatabase.ts               # Utility: drops the DB
    migrations/
      001_create_users_table.sql
      002_create_auth_tokens_table.sql
      003_create_tenants_table.sql
      004_create_staff_table.sql
  routes/
    index.ts                      # Mounts all sub-routers under /api
    health.routes.ts              # GET /api/health
    auth.routes.ts                # POST /api/auth/register, POST /api/auth/login
    tenant.routes.ts              # GET /api/tenants, POST /api/tenants, GET /api/tenants/:id, PUT /api/tenants/:id
  controllers/
    health.controller.ts
    auth.controller.ts            # register and login handlers
    tenant.controller.ts          # getAll, create, getById, update handlers
  middlewares/
    cors.ts                       # Manual CORS headers (no external library)
    authenticate.ts               # Bearer token validation middleware
    errorHandler.ts               # Catch-all error handler → 500
  models/
    user.model.ts                 # User interface + repository (findByEmail, findById, createUser)
    auth-token.model.ts           # AuthToken interface + createAuthToken, findByHash
    tenant.model.ts               # Tenant interface + createTenant, getTenantsByUserId, getById, getBySlug, updateTenant
  utils/
    crypto.ts                     # hashPassword, verifyPassword, generateToken, hashToken
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `APP_PORT` | `3000` | HTTP server port |
| `NODE_ENV` | `development` | Environment (`development` / `test` / `production`) |
| `DB_HOST` | — (required) | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | — (required) | Database name |
| `DB_USER` | — (required) | PostgreSQL user |
| `DB_PASSWORD` | — (required) | PostgreSQL password |
| `CORS_ORIGIN` | `*` | Allowed CORS origin |
| `DB_ADMIN_DB` | `postgres` | Admin DB for create/drop scripts |

### API endpoints

All endpoints are mounted under `/api`.

| Method | Route | Auth | Description |
|---|---|---|---|
| GET | `/api/health` | No | API + DB connectivity status |
| POST | `/api/auth/register` | No | Register a new user, returns a token |
| POST | `/api/auth/login` | No | Authenticate user, returns a token |
| GET | `/api/tenants` | Bearer | List all tenants |
| POST | `/api/tenants` | Bearer | Create a new tenant |
| GET | `/api/tenants/:id` | Bearer | Get tenant by ID |
| PUT | `/api/tenants/:id` | Bearer | Update one or more tenant fields |

### Request flow

```
HTTP Client
    │
    ▼
corsMiddleware          → Adds CORS headers; responds OPTIONS with 204
    │
    ▼
express.json()          → Parses JSON body
    │
    ▼
apiRouter (/api)        → Routes to health / auth / tenants
    │
    ├── [auth/health routes]  → controller directly
    │
    └── [tenant routes]
            │
            ▼
        authenticate    → Extracts Bearer token, SHA-256 hashes it, queries auth_tokens
            │
            ▼
        controller      → Validates input → calls model → shapes HTTP response
            │
            ▼
        model           → Executes parameterized SQL via dbPool (pg.Pool)
            │
            ▼
        PostgreSQL
    │
    ▼
errorHandler            → Catches any unhandled error → standard 500
```

### Database tables

| Table | Key columns |
|---|---|
| **users** | `id` UUID PK, `email` UNIQUE, `password_hash`, `created_at`, `updated_at` |
| **auth_tokens** | `id` UUID PK, `user_id` FK→users (CASCADE), `token_hash` UNIQUE, `expires_at` |
| **tenants** | `id` UUID PK, `user_id` UUID (no FK constraint), `name`, `slug` UNIQUE, `settings` JSONB `{goal, reward, cooldown_hours}` |
| **staff** | `id` UUID PK, `tenant_id` UUID FK→tenants(id), `name`, `pin_hash`, `created_at`; UNIQUE(tenant_id, name) |
| **schema_migrations** | Internal migration tracking (`filename` UNIQUE, `applied_at`) |

Indexes: `idx_users_email`, `idx_auth_tokens_user_id`, `idx_auth_tokens_token_hash`, `idx_tenants_slug`, `idx_staff_tenant_id`.

### Middlewares

- **cors.ts**: Manual CORS (no external library). Origin controlled by `CORS_ORIGIN`. Handles preflight OPTIONS with 204.
- **authenticate.ts**: Extracts Bearer token from `Authorization` header, SHA-256 hashes it, queries `auth_tokens` for a non-expired match.
- **errorHandler.ts**: Express 4-parameter error handler. Catch-all — always returns `500`.

### utils/crypto.ts

All cryptography uses Node.js native `crypto` module (no external dependencies):

| Function | Algorithm | Notes |
|---|---|---|
| `hashPassword(password)` | scrypt + random salt | Returns `"<salt>:<derivedKey>"` |
| `verifyPassword(password, hash)` | scrypt + timingSafeEqual | Timing-safe comparison |
| `generateToken()` | randomBytes(32) | 64-char hex opaque token |
| `hashToken(token)` | SHA-256 | Only the hash is stored in DB |

### Scripts

| Script | Description |
|---|---|
| `npm run dev` | Hot-reload dev server (ts-node-dev) |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Run compiled build |
| `npm run migrate` | Apply pending SQL migrations |
| `npm run db:create` | Create the database if it does not exist |
| `npm run db:drop` | Drop the database |

### Key technical decisions

- Opaque tokens stored as SHA-256 hash — plain token sent to client only, never persisted.
- Native `scrypt` instead of bcrypt to avoid native compiled dependencies.
- Manual CORS — no `cors` npm package.
- No ORM — raw parameterized SQL through `pg.Pool`.
- Single shared `dbPool` imported by all model files.
- All `process.env` access centralized in `config/env.ts`.
- Early returns in all controllers and middlewares — no nested conditionals.
