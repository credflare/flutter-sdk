import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'client.dart';

enum LocationAccess { granted, denied, serviceDisabled }

class LocationUnavailable implements Exception {
  const LocationUnavailable();
}

abstract class LocationSource {
  Future<LocationAccess> requestAccess();

  Future<LocationFix> currentFix(Duration timeout);
}

class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse
        ? LocationAccess.granted
        : LocationAccess.denied;
  }

  @override
  Future<LocationFix> currentFix(Duration timeout) async {
    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: timeout,
        ),
      );
    } on LocationServiceDisabledException {
      throw const LocationUnavailable();
    }
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.hasAccuracy ? position.accuracy : null,
      altitude: position.hasAltitude ? position.altitude : null,
      fixTime: position.timestamp,
      isMock: Platform.isAndroid || Platform.isIOS ? position.isMocked : null,
      provider: 'fused',
      capturedAt: DateTime.now(),
    );
  }
}
