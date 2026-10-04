# Kit de publicación en Play Store — VoyContigo

Todo lo que pide Play Console, listo para copiar y pegar.
Archivo a subir: `build/app/outputs/bundle/release/app-release.aab`

---

## 1. Ficha de la tienda (Store listing)

**Nombre de la app** (máx. 30 caracteres):
```
VoyContigo: Machachi–Quito
```

**Descripción corta** (máx. 80 caracteres):
```
Viajes compartidos por paraderos entre Machachi y Quito. Comparte y ahorra.
```

**Descripción completa** (máx. 4000 caracteres):
```
🚗 VoyContigo es la comunidad de viajes compartidos del corredor Machachi–Quito.

¿Viajas todos los días entre Machachi y Quito? Miles de personas hacen el mismo trayecto a la misma hora, cada quien por su lado. VoyContigo los conecta: los conductores publican su ruta y los pasajeros reservan un cupo, como una línea de bus… pero en los carros de tu propia comunidad.

🚏 POR PARADEROS, NO PUERTA A PUERTA
Elige dónde te subes y dónde te bajas tocando la línea de paraderos del corredor: Parque Central, El Caballito, Redondel Norte, Quicentro Sur, El Trébol, La Marín, U. Católica y más. Cada paradero se puede ver en el mapa, y el conductor señala el punto exacto por el que pasa.

🤝 COINCIDENCIAS AUTOMÁTICAS
Publica tu viaje y la app te avisa cuando aparece un conductor o pasajero compatible con tu horario y tu tramo.

🛡️ PENSADA PARA LA CONFIANZA
• Conductores verificados manualmente por nuestro equipo (licencia y vehículo).
• Calificaciones entre usuarios después de cada viaje.
• Contacto de emergencia y botón SOS durante el viaje.
• Seguimiento en vivo del conductor cuando el viaje está en curso.

🔔 SIEMPRE AL TANTO
Notificaciones cuando aceptan tu viaje, cuando el conductor va en camino, cuando está a pocos minutos de tu paradero, y recordatorios antes de cada salida programada.

🎫 CLUB DE BENEFICIOS
Cada viaje completado estampa un sello en tu tarjeta. Llena tu papeleta, raspa tus cupones y canjea premios en locales del corredor: cafés, lavado de auto, cine y más.

📅 VIAJES PROGRAMADOS Y RECURRENTES
¿Sales todos los días a la misma hora? Publica tu viaje una vez y repítelo los días que elijas.

VoyContigo es una plataforma de contacto entre particulares que comparten gastos del trayecto: sin comisiones, sin tarifas ocultas, sin anuncios.

Tu viaje. Tus reglas. 💜
```

**Categoría**: Aplicaciones → Mapas y navegación (alternativa: Viajes y guías)
**Correo de contacto**: jaunse665@gmail.com
**Política de privacidad (URL)**: https://voycontigo-1a327.web.app/privacidad.html

**Recursos gráficos requeridos**:
- Icono: 512×512 px, PNG (sin transparencia de fondo)
- Gráfico destacado: 1024×500 px, PNG/JPG
- Capturas de teléfono: mínimo 2 (están en `store_assets/screenshots/`)

---

## 2. Formulario "Seguridad de los datos" (Data safety)

> En Play Console: Política → Contenido de la app → Seguridad de los datos.

**¿Recoge o comparte datos?** Sí, recoge. **No comparte** datos con terceros
(el intercambio entre usuarios de un mismo viaje no cuenta como "compartir";
Firebase actúa como encargado del tratamiento).

| Dato | ¿Se recoge? | ¿Opcional? | Finalidad |
|---|---|---|---|
| Ubicación precisa | Sí | No (necesaria para la función principal) | Funcionalidad de la app |
| Ubicación aproximada | Sí | No | Funcionalidad de la app |
| Nombre | Sí | No | Funcionalidad, gestión de cuenta |
| Correo electrónico | Sí | No | Funcionalidad, gestión de cuenta |
| Número de teléfono | Sí | Sí (coordinación/SOS) | Funcionalidad de la app |
| Mensajes dentro de la app (chat) | Sí | Sí | Funcionalidad de la app |
| IDs del dispositivo (token de notificaciones) | Sí | No | Funcionalidad de la app |
| Historial de la app (viajes) | Sí | No | Funcionalidad de la app |
| Registros de fallos (Crashlytics) | Sí | No | Analytics / diagnóstico |

**¿Datos cifrados en tránsito?** Sí.
**¿El usuario puede solicitar la eliminación?** Sí — vía WhatsApp +593 99 928 4698
(declara el mismo canal en "Eliminación de datos y cuenta").

---

## 3. Declaraciones de política

**Servicio en primer plano (API 34+)** — tipo `location`:
```
VoyContigo comparte la ubicación del conductor con los pasajeros confirmados
únicamente mientras un viaje compartido está activo (desde que el conductor
toca "Iniciar Viaje" hasta que finaliza), con una notificación visible
permanente. Es la función principal de seguimiento del viaje.
```

**Permisos sensibles**: la app NO usa ubicación en segundo plano
(ACCESS_BACKGROUND_LOCATION fue retirado del manifest).

---

## 4. Clasificación de contenido (cuestionario IARC)

Respuestas clave:
- Violencia, sexo, drogas, apuestas: **No** en todo.
- ¿Los usuarios pueden interactuar o intercambiar contenido? **Sí**
  (chat entre participantes de un viaje) → esto es normal, dará una
  clasificación tipo "Supervisión parental recomendada".
- ¿Comparte la ubicación del usuario con otros usuarios? **Sí**
  (durante el viaje activo).
- ¿Compras digitales? **No**.

---

## 5. Configuración de la ficha

- **Tipo**: App gratuita, sin anuncios, sin compras en la app.
- **Países**: Ecuador (agrega más si quieres).
- **Público objetivo**: 18+.
- **Audiencia infantil**: No dirigida a niños.

---

## 6. Secuencia en la consola (resumen)

1. Crear cuenta de desarrollador ($25) + verificación de identidad (1–3 días).
2. "Crear app" → nombre, idioma español (Latinoamérica), app gratuita.
3. Completar TODOS los puntos de "Panel → Configura tu app" usando las
   secciones 1–5 de este documento.
4. Prueba cerrada: crear track → subir el .aab → lista de correos de
   12+ testers → compartir el enlace de participación.
5. Mantener la prueba 14 días con los testers activos → solicitar
   acceso a producción → revisión de Google (1–7 días) → publicar.

Cada nueva versión que se suba debe incrementar `version:` en
`pubspec.yaml` (ej. `1.0.1+2`) antes de `flutter build appbundle --release`.
