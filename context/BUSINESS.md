# Business Rules

Este documento describe las reglas funcionales principales del sistema.

---

# Entidades

## User
Cuenta de la plataforma.

Puede tener múltiples tenants.

---

## Tenant
Negocio que opera un programa de fidelización.

Campos:

- name
- slug (único global)
- settings
  - goal
  - reward
  - cooldown_hours

Un usuario puede tener múltiples tenants.

Solo el dueño del tenant puede administrarlo.

---

## Staff

Empleado que opera el sistema.

Campos:

- name
- pin

Reglas:

- pertenece a un único tenant
- name debe ser único dentro del tenant
- PIN debe ser numérico de 4–6 dígitos
- el PIN siempre se almacena como hash

Staff NO es usuario de la plataforma.

No tiene email ni sesión persistente.

---

# Flujos principales

## Registro de usuario

1. usuario se registra con email y password
2. recibe token de autenticación

---

## Gestión de tenants

Usuario puede:

- crear tenants
- listar tenants
- editar settings

Al crear tenant:

- slug se genera automáticamente desde name
- puede editarse antes de guardar

---

## Gestión de staff

El dueño del tenant puede:

- listar staff
- crear staff

Validaciones:

- name único por tenant
- PIN válido

---

## Login de staff

Flujo:

1. staff accede a `/staff/login`
2. tenant se identifica por `?tenant_id=`
3. selecciona nombre
4. introduce PIN
5. API devuelve:

id  
name  
tenant_id

si las credenciales son válidas
