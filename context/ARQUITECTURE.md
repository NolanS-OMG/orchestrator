# Arquitectura General

El sistema se divide en dos apps:

- `blue-api`: backend HTTP.
- `blue-web`: frontend web.

## Backend (`blue-api`)

Stack: Node.js + TypeScript + Express + PostgreSQL.

Estructura (`src/`):

- `index.ts`: arranque de la API.
- `config/`: variables de entorno.
- `db/`: conexión, scripts y migraciones.
- `routes/`: rutas (`health`, `auth`, `tenants`, `staff`).
- `controllers/`: capa HTTP (entrada/salida).
- `models/`: acceso a datos con SQL directo.
- `middlewares/`: CORS, auth, errores.
- `utils/`: criptografía.

Convenciones clave:

- Prefijo global: `/api`.
- Controladores delgados; lógica de datos en `models`.
- Solo `config/env.ts` lee `process.env`.
- Tokens opacos (hash SHA-256) con expiración de 7 días.

Tablas principales:

- `users`
- `auth_tokens`
- `tenants`
- `staff`

Scripts útiles:

- `npm run dev`, `npm run build`, `npm start`
- `npm run migrate`, `npm run db:create`, `npm run db:drop`

## Frontend (`blue-web`)

Stack: React + TypeScript + Vite.

Estructura (`src/`):

- `api.ts`: cliente HTTP compartido.
- `auth/tokenService.ts`: sesión y token.
- `router/`: árbol de rutas y guards.
- `hooks/useStateApi.ts`: estado genérico de requests.
- `components/`: módulos funcionales.
- `data/translation/es.json`: textos UI.
- `index.css`: tokens globales de diseño.

Módulos principales:

- Auth: `InitSession`, `PublicRoute`, `PrivateRoute`.
- Dashboard: `Dashboard`.
- Tenants: `TenantList`, `CreateTenant`, `TenantDetail`.
- Staff: `Staff`, `StaffLogin`.
- Shared/Fallback: `Layout`, `NotFound`.

Rutas principales:

- `/login`, `/register` (públicas)
- `/dashboard`, `/tenants`, `/tenants/new`, `/tenants/:tenantId` (privadas)
- `/tenants/:tenantId/staff`, `/tenants/:tenantId/staff/new` (privadas)
- `/staff/login` (pública)

Convenciones clave:

- Patrón por componente: `styles/`, `hooks/`, `data/`.
- Hooks de API montados sobre `useStateApi`.
- Strings centralizados en `es.json`.

Runtime:

- Env requerida: `VITE_API_URL`.
- Scripts: `npm run dev`, `npm run build`, `npm run lint`, `npm run preview`.
