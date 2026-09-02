/// Catálogo de paraderos del corredor Machachi ↔ Quito.
///
/// VoyContigo no es puerta a puerta: los viajes se suben y bajan en
/// paraderos conocidos del corredor, como una línea de bus. Esta es la
/// fuente única de verdad; agregar un paradero nuevo es agregar una
/// entrada aquí (en el orden físico del recorrido saliendo de Machachi).
class RouteStop {
  final String id;
  final String name;

  /// Referencia física para encontrarlo ("Monumento a la entrada", etc.).
  final String reference;
  final double lat;
  final double lng;

  /// true = lado Machachi del corredor; false = lado Quito.
  final bool isMachachiSide;

  const RouteStop({
    required this.id,
    required this.name,
    required this.reference,
    required this.lat,
    required this.lng,
    required this.isMachachiSide,
  });
}

/// Paraderos en orden de recorrido Machachi ➔ Quito.
const List<RouteStop> corridorStops = [
  // --- Machachi ---
  RouteStop(
    id: 'parque_central',
    name: 'Parque Central',
    reference: 'Centro de Machachi',
    lat: -0.5097,
    lng: -78.5672,
    isMachachiSide: true,
  ),
  RouteStop(
    id: 'el_aki',
    name: 'El Aki',
    reference: 'Supermercado Akí, Machachi',
    lat: -0.5100,
    lng: -78.5650,
    isMachachiSide: true,
  ),
  RouteStop(
    id: 'redondel_norte',
    name: 'Redondel Norte',
    reference: 'Salida norte de Machachi',
    lat: -0.5000,
    lng: -78.5670,
    isMachachiSide: true,
  ),
  RouteStop(
    id: 'el_caballito',
    name: 'El Caballito',
    // Coordenada aproximada del monumento en la Panamericana;
    // ajustar si hace falta afinarla.
    reference: 'Monumento en la Panamericana',
    lat: -0.4936,
    lng: -78.5629,
    isMachachiSide: true,
  ),
  // --- Quito (llegando desde el sur) ---
  RouteStop(
    id: 'quicentro_sur',
    name: 'Quicentro Sur',
    reference: 'Av. Morán Valverde, sur de Quito',
    lat: -0.28477,
    lng: -78.54487,
    isMachachiSide: false,
  ),
  RouteStop(
    id: 'el_trebol',
    name: 'El Trébol',
    reference: 'Intercambiador El Trébol',
    lat: -0.2289,
    lng: -78.5028,
    isMachachiSide: false,
  ),
  RouteStop(
    id: 'la_marin',
    name: 'La Marín',
    reference: 'Terminal La Marín, centro',
    lat: -0.2236,
    lng: -78.5042,
    isMachachiSide: false,
  ),
  RouteStop(
    id: 'u_catolica',
    name: 'U. Católica',
    reference: 'Av. 12 de Octubre',
    lat: -0.2104,
    lng: -78.4907,
    isMachachiSide: false,
  ),
];

/// Paraderos en el orden del viaje según la dirección elegida.
List<RouteStop> stopsForDirection({required bool outbound}) =>
    outbound ? corridorStops : corridorStops.reversed.toList();

/// Busca un paradero por nombre exacto (para re-sincronizar al editar
/// un viaje guardado). Devuelve null si el punto fue elegido en el mapa.
RouteStop? findStopByName(String name) {
  for (final stop in corridorStops) {
    if (stop.name == name) return stop;
  }
  return null;
}
