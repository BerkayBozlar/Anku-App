import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Tandoğan kampüsü haritası (ilk deneme).
/// Bina/tesis işaretleri, arama ve GPS 7. haftada eklenecek.
class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  // Fen ve Mühendislik fakülteleri çevresi, yaklaşık merkez
  static const tandogan = LatLng(39.9365, 32.8305);
  static const initialZoom = 15.5;

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  MapLibreMapController? _controller;

  void _recenter() {
    _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(
        CampusMapScreen.tandogan,
        CampusMapScreen.initialZoom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tandoğan Kampüsü')),
      body: MapLibreMap(
        styleString: 'assets/map/osm_style.json',
        initialCameraPosition: const CameraPosition(
          target: CampusMapScreen.tandogan,
          zoom: CampusMapScreen.initialZoom,
        ),
        minMaxZoomPreference: const MinMaxZoomPreference(11, 19),
        compassEnabled: true,
        onMapCreated: (controller) => _controller = controller,
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Kampüse dön',
        onPressed: _recenter,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
