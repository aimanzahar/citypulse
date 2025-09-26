import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/i18n.dart';
import '../../services/location_service.dart';
import '../../services/mock_ai.dart';
import '../../models/report.dart';
import '../../models/enums.dart';
import 'review_screen.dart';
 
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
          SnackBar(content: Text('Error picking image: $e')),
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
      // Get current position (Geolocator.Position)
      final position = await LocationService.getCurrentPosition();
 
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to get location. Please try again.')),
          );
        }
        return;
      }
 
      // Convert Position -> LocationData (app model)
      final locationData = LocationService.positionToLocationData(position);
 
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
            builder: (context) => ReviewScreen(report: report, imageFile: File(image.path)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    debugPrint('[i18n] CaptureScreen: locale=${I18n.currentLocale} prompt=${I18n.t('capture.prompt')}');
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('nav.report')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              I18n.t('capture.prompt'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(I18n.t('btn.camera')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(I18n.t('btn.gallery')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}