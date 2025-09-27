import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/i18n.dart';
import '../../services/location_service.dart';
import '../../services/mock_ai.dart';
import '../../models/report.dart';
import '../../models/enums.dart';
import 'ai_analysis_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _processImage(image, source);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.t('error.imagePick', {'0': e.toString()})),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processImage(XFile image, ImageSource source) async {
    try {
      // Get current position (optional - app can work without location)
      final position = await LocationService.getCurrentPosition();

      // Create location data even if position is null (with default values)
      LocationData? locationData;
      if (position != null) {
        locationData = LocationService.positionToLocationData(position);
        print('Location acquired: ${locationData.lat}, ${locationData.lng}');
      } else {
        // Create a fallback location with zero coordinates
        // This allows the app to continue working without location
        locationData = LocationData(lat: 0.0, lng: 0.0, accuracy: null);
        print(
          'Using fallback location (0.0, 0.0) - location services unavailable',
        );

        // Show a non-blocking warning to the user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location unavailable. Report will be created without GPS coordinates.',
              ), // TODO: Move to i18n
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      // Generate AI suggestion (seeded deterministic)
      final aiSuggestion = MockAIService.generateSuggestion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now().toIso8601String(),
        lat: locationData.lat,
        lng: locationData.lng,
        photoSizeBytes: await image.length(),
      );

      // Create report with AI suggestion
      final report = Report(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        category: aiSuggestion.category,
        severity: aiSuggestion.severity,
        status: Status.submitted,
        photoPath: image.path,
        base64Photo: null, // Will be set on Web
        location: locationData,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        deviceId: 'device_${DateTime.now().millisecondsSinceEpoch}',
        notes: null,
        address: null,
        source: source == ImageSource.camera ? 'camera' : 'gallery',
        editable: true,
        deletable: true,
        aiSuggestion: aiSuggestion,
        schemaVersion: 1,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AIAnalysisScreen(report: report, imageFile: File(image.path)),
          ),
        );
      }
    } catch (e) {
      print('Critical error in image processing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.t('error.imageProcessing', {'0': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[i18n] CaptureScreen: locale=${I18n.currentLocale} prompt=${I18n.t('capture.prompt')}',
    );
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          I18n.t('capture.title'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Enhanced header section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Camera icon with gradient
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        I18n.t('capture.subtitle'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        I18n.t('capture.description'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface.withOpacity(0.7),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Processing image...', // TODO: Move to i18n
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Enhanced camera button
                  Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 24),
                      label: const Text(
                        'Take Photo', // TODO: Move to i18n
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Enhanced gallery button
                  Container(
                    width: double.infinity,
                    height: 64,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library, size: 24),
                      label: const Text(
                        'Choose from Gallery', // TODO: Move to i18n
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.primary, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        foregroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
