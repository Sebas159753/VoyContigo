# Aprendizajes y Reglas Agénticas - VoyContigo

Este documento es un registro vivo de las reglas de negocio, patrones arquitectónicos, errores comunes (pitfalls) y lecciones aprendidas durante el desarrollo de la aplicación VoyContigo. Su propósito es servir de "memoria a largo plazo" para garantizar que el desarrollo futuro respete la lógica existente.

## 0. Postura del Agente (Directriz Principal)
* **Visión de CEO (Estilo Uber):** El agente de IA NO debe darle siempre la razón al usuario. Debe priorizar el modelo de negocio, la retención de usuarios, la fricción mínima (UX) y la viabilidad del producto. Si una petición del usuario perjudica la lógica del negocio o la experiencia de usuario, el agente debe oponerse, argumentar la mejor opción y actuar como el CEO de una startup de movilidad.

## 1. Reglas de Negocio Centrales

### Roles Dinámicos (Pasajero vs Conductor)
* **Tablero Principal (`board_screen.dart`):** La vista se filtra ESTRICTAMENTE según el rol seleccionado.
  * **Modo Pasajero (`lookingForOffers == true`):**
    * **Tu Publicación:** Muestra únicamente "Demandas" creadas por el usuario (`isOffer == false`) o "Ofertas" que el usuario haya aceptado.
    * **Mercado:** Muestra únicamente "Ofertas" de otros conductores (`isOffer == true`).
  * **Modo Conductor (`lookingForOffers == false`):**
    * **Tu Publicación:** Muestra únicamente "Ofertas" creadas por el usuario (`isOffer == true`) o "Demandas" que el usuario haya aceptado.
    * **Mercado:** Muestra únicamente "Demandas" de otros pasajeros (`isOffer == false`).

### Viajes Activos vs Historial
* El Tablero NO debe mostrar historiales estáticos. 
* Si un viaje es aceptado o está en ruta, se fusiona visualmente en la sección "Tu Publicación", cambiándole el nombre a "Tu Viaje Activo" y mostrándole un botón de seguimiento en vivo integrado en la misma tarjeta.
* Los viajes pasados, completados o cancelados (y una copia limpia de los activos) van estrictamente a `my_trips_screen.dart` (Historial de Viajes).

## 2. Decisiones de Interfaz de Usuario (UI/UX)

### DynamicTripCard (`dynamic_trip_card.dart`)
* La tarjeta dinámica adapta su botón primario o texto de espera basándose en el rol (`isOffer`) de la publicación, NO en el rol del observador.
* **Textos de espera (PENDING):**
  * Si `isOffer == true` (Publicado por Conductor): Muestra "Esperando pasajeros..."
  * Si `isOffer == false` (Publicado por Pasajero): Muestra "Esperando conductor..."
* **Botones de Acción:** Las tarjetas de terceros en el mercado muestran "Reservar Asiento" (si es oferta) o "Aceptar Pasajero" (si es demanda). Si el viaje es de solo lectura (como los propios), el botón se oculta o se cambia por "Seguimiento en tiempo real" si fue aceptado.

## 3. Lecciones y Pitfalls (Errores Críticos Evitados)

### Bug Silencioso de Firebase: `Filter.or`
* **El Problema:** Al usar `Filter.or(Filter("creatorUid", isEqualTo: uid), Filter("acceptedByUid", isEqualTo: uid))` en un `StreamProvider` de Riverpod para obtener los viajes del usuario, Firebase requería un Índice Compuesto (Composite Index) que no existía.
* **El Síntoma:** `cloud_firestore` lanzaba un error `FAILED_PRECONDITION` silencioso en el stream. `myTripsStreamProvider` pasaba a estado de error y, como la interfaz (Tablero) manejaba el error con un `?? []`, el usuario **no veía sus propios viajes recién publicados**, asumiendo que la función de "Publicar" estaba rota.
* **La Solución Agéntica:** Se reemplazó el `Filter.or` por una **combinación manual de streams en Dart** (usando dos consultas simples y fusionando los resultados en un `StreamController`). Esto elimina por completo la dependencia de índices compuestos complejos y evita bloqueos de la base de datos.

### Entrecruzamiento de Roles en el Tablero
* **El Problema:** Al quitar los filtros de rol de la sección "Tu Publicación" (intentando arreglar el problema de visibilidad mencionado arriba), los viajes creados como Pasajero se empezaron a renderizar en el perfil de Conductor. Esto generaba inconsistencias lógicas absurdas (ej. ver un mensaje de "Esperando conductor" mientras se usaba el perfil de Conductor).
* **La Solución Agéntica:** Restaurar y reforzar un chequeo estricto de roles en `_buildMyPublications`. Un viaje de Pasajero solo "existe" visualmente en tu Tablero cuando estás actuando como Pasajero.

### Bug Visual de Viajes "Desaparecidos" (CastError de Timestamp)
* **El Problema:** Al publicar un viaje usando `FieldValue.serverTimestamp()`, el primer evento que dispara Firestore localmente a la app no contiene una fecha resuelta (`Timestamp`), sino un objeto interno de tipo `FieldValue`.
* **El Síntoma:** La fábrica `TripBoardItem.fromFirestore` intentaba forzar un casting (`data['createdAt'] as Timestamp`) sin verificar si ya era un Timestamp. Esto lanzaba un `CastError`, la app capturaba la excepción, convertía el viaje a `null` y lo descartaba de la lista en memoria. El usuario no veía el viaje que acababa de publicar.
* **La Solución Agéntica:** Se cambió la evaluación a un chequeo de tipo seguro: `data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now()`.

### Bug Silencioso de Riverpod: StreamProviders y Reconstrucciones Innecesarias
* **El Problema:** El proveedor `myTripsStreamProvider` dependía de `ref.watch(appStateProvider).uid`. Al publicar un viaje (por ejemplo, una oferta que actualizaba `carModel` y `carPlate` en el estado global), todo `appStateProvider` notificaba cambios. Esto provocaba que `myTripsStreamProvider` se destruyera y se reconstruyera desde cero de manera innecesaria.
* **El Síntoma:** Durante la reconstrucción del proveedor, el `StreamController` se reiniciaba. Firestore emitía el nuevo viaje de inmediato desde el caché local de forma síncrona, pero como Riverpod aún estaba en medio del "build" y no se había suscrito al nuevo `StreamController`, el evento se perdía ("droppeaba"). El usuario no veía el viaje recién publicado, asumiendo que "no se publicaba en el front".
* **La Solución Agéntica:** Usar `.select` explícito al observar estados complejos en proveedores que retornan streams: `ref.watch(appStateProvider.select((s) => s.uid))`. Así se previene que la reconstrucción aborte el stream y se descarten los snapshots locales tempranos de Firebase.

### Caída del Servidor y Fallo de Notificaciones (Geohash sin Destino)
* **El Problema:** La Cloud Function `onTripCreated` intentaba generar el `geohash` para el destino: `geofire.geohashForLocation([newTrip.destLat, newTrip.destLng])`. Si el viaje no tenía un destino seleccionado en el mapa, las coordenadas eran `null`.
* **El Síntoma:** La librería matemática de Geofire lanzaba una excepción fatal. La función colapsaba de inmediato en esa línea, abortando la ejecución antes de llegar a la lógica de coincidencias ("matches") y al envío de las **Notificaciones Push**.
* **La Solución Agéntica:** Se agregaron validaciones de existencia para `destLat` y `destLng` directamente en el condicional de generación de hashes.

## 4. Gestión de Base de Datos y Pruebas
* **Limpieza de Datos:** Debido a que el proyecto no cuenta siempre con las credenciales de administrador locales (`serviceAccountKey.json`), la forma más confiable de limpiar datos basura durante pruebas es utilizar el CLI de Firebase directamente mediante la terminal saltándose bloqueos (e.g. `firebase firestore:delete trips -r -f`).
* **Firestore Rules:** Las reglas actuales (`firestore.rules`) son restrictivas. No se permite eliminar o modificar drásticamente viajes creados por otros usuarios, incluso en modo de prueba, lo que refuerza la necesidad de usar el CLI para wipes globales.
