# Blueprint — Business Logic

Blueprint es un SaaS de fidelización para negocios físicos que reemplaza tarjetas de cartón por una billetera digital basada en número de teléfono.

El sistema permite que empleados (staff) registren visitas y recompensas de clientes.

---

# Identidad

Identificador principal del cliente:

phone (E.164)

El mismo cliente puede participar en múltiples negocios.

---

# Entidades

## Tenant
Negocio que opera un programa de fidelización.

Campos relevantes:
- id
- name
- slug (único global)
- settings
  - goal
  - reward
  - cooldown_hours

---

## Staff
Empleado que opera el sistema.

Campos:
- id
- tenant_id
- name
- pin_hash

Autenticación:
PIN numérico de 4–6 dígitos.

---

## Customer
Identidad universal del cliente.

Campos:
- id
- phone (único global)
- name (opcional)

---

## Loyalty Card
Relación entre cliente y negocio.

Campos:
- customer_id
- tenant_id
- current_points
- last_visit

Un cliente puede tener múltiples tarjetas (una por negocio).

---

## Master Logs
Libro mayor inmutable de transacciones.

Regla crítica:

- solo INSERT
- nunca UPDATE
- nunca DELETE

Campos:
- id
- tenant_id
- staff_id
- customer_id
- action (ADD, REDEEM, ADJUST)
- points_changed
- metadata

---

# Reglas críticas

## Acumulación de puntos

Cuando el staff agrega puntos:

1. validar que staff pertenezca al tenant
2. verificar cooldown desde último ADD
3. ejecutar transacción atómica:

INSERT master_logs

UPSERT loyalty_cards (incrementar puntos)

---

## Cooldown

Un cliente no puede registrar visitas dentro de:

settings.cooldown_hours

---

## Integridad

El balance de puntos nunca puede cambiar sin registrar un evento en master_logs.

---

# QR Universal

El QR del cliente contiene:

customer_id codificado.

La Staff App lo escanea y ejecuta la acción dentro del tenant activo.

---

# Estrategia Offline

La Staff App debe ser offline-first.

Si no hay red:

1. guardar transacción en IndexedDB
2. marcar como pending
3. sincronizar FIFO cuando vuelva la conexión

---

# Reglas para IA

- nunca modificar puntos directamente
- siempre registrar transacciones en master_logs
- validar cooldown
- respetar aislamiento entre tenants