import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Controlador del Mapa
  final MapController _mapController = MapController();
  
  // Coordenadas iniciales (Quito, Ecuador)
  LatLng _currentCenter = const LatLng(-0.22985, -78.52495);
  String _currentAddressName = "Ubicación Seleccionada";
  // true si el pin sigue en el resultado buscado; false si el usuario arrastró.
  bool _pinnedFromSearch = false;

  // Buscador
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.length < 3) {
      setState(() { _searchResults = []; });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        // Añadimos viewbox para priorizar resultados en la zona de Pichincha (Quito/Machachi)
        // viewbox = left(lon), top(lat), right(lon), bottom(lat)
        final String viewbox = "-79.5,0.5,-77.5,-1.0";
        final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(query)}&format=json&limit=5&countrycodes=ec&viewbox=$viewbox');
        final response = await http.get(url, headers: {'User-Agent': 'VoyContigoApp/1.0'});
        
        if (response.statusCode == 200) {
          List<dynamic> results = json.decode(response.body);
          
          // Ordenar localmente para dar prioridad a centros urbanos (town/city/village) 
          // sobre cantones enteros (county) o lugares turísticos.
          results.sort((a, b) {
            final aAddressType = a['addresstype'] ?? a['type'] ?? '';
            final bAddressType = b['addresstype'] ?? b['type'] ?? '';
            
            final aIsUrban = ['city', 'town', 'village'].contains(aAddressType);
            final bIsUrban = ['city', 'town', 'village'].contains(bAddressType);
            
            if (aIsUrban && !bIsUrban) return -1;
            if (!aIsUrban && bIsUrban) return 1;
            
            return 0;
          });

          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        setState(() => _isSearching = false);
      }
    });
  }

  void _selectResult(dynamic result) {
    FocusScope.of(context).unfocus(); // Ocultar teclado
    final lat = double.parse(result['lat']);
    final lon = double.parse(result['lon']);
    final newLocation = LatLng(lat, lon);
    
    setState(() {
      _searchResults = [];
      _searchCtrl.text = result['display_name'].toString().split(',').first;
      _currentAddressName = _searchCtrl.text;
      // El pin y las coordenadas devueltas deben ir al lugar buscado.
      _currentCenter = newLocation;
      _pinnedFromSearch = true;
    });

    _mapController.move(newLocation, 16.0);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: Stack(
        children: [
          // Mapa Interactivo Real
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  _currentCenter = camera.center;
                  // Al arrastrar, el nombre buscado ya no corresponde al pin.
                  _pinnedFromSearch = false;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.voycontigo.voycontigo',
              ),
            ],
          ),
          
          // Chincheta flotante con instrucción
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: const Text(
                      'Arrastra el mapa para esquinas exactas',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.location_on, size: 50, color: Colors.black),
                ],
              ),
            ),
          ),

          // Área de Búsqueda Superior
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black54),
                        onPressed: () => context.pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Buscar calle o lugar (ej. Quicentro)...",
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_isSearching) 
                        const SizedBox(
                          width: 20, height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                        )
                    ],
                  ),
                ),
                
                // Resultados de autocompletado
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        final addressType = result['addresstype'] ?? result['type'] ?? '';
                        String typeLabel = '';
                        if (addressType == 'county') typeLabel = ' (Cantón/Zona)';
                        else if (addressType == 'town' || addressType == 'city') typeLabel = ' (Centro Urbano)';
                        else if (addressType == 'village') typeLabel = ' (Pueblo)';
                        else typeLabel = ' ($addressType)';

                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text("${result['display_name'].toString().split(',').first}$typeLabel", style: AppTheme.bodyFont(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(result['display_name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          onTap: () => _selectResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          // Botón inferior
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
              ),
              onPressed: () {
                // Usa el nombre buscado solo si el pin sigue ahí; si arrastraste, usa coordenadas.
                String finalLocation = (_pinnedFromSearch && _searchCtrl.text.isNotEmpty)
                    ? _currentAddressName
                    : "${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)}";
                context.pop({
                  'address': finalLocation,
                  'lat': _currentCenter.latitude,
                  'lng': _currentCenter.longitude,
                });
              },
              child: Text('Confirmar Ubicación', style: AppTheme.bodyFont(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
