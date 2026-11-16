import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

class AnotherPage extends StatefulWidget {
  final CameraDescription camera;

  const AnotherPage({super.key, required this.camera});

  @override
  State<AnotherPage> createState() => _AnotherPageState();
}

class _AnotherPageState extends State<AnotherPage> {
  String result = '';
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  File? capturedImage;
  final speech = FlutterTts();
  late FlutterTts _flutterTts;
  bool isSpeaking = false;
  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
    _initTts();
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setStartHandler(() {
      setState(() {
        isSpeaking = true;
      });
    });
    _flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> _speakOrStop() async {
    if (isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        isSpeaking = false;
      });
    } else {
      var result = await _flutterTts.speak("hello can you hear me");
      if (result == 1) {
        setState(() {
          isSpeaking = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _flutterTts.stop();

    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final XFile image = await _controller.takePicture();
      final savedImage = File(image.path);
      setState(() {
        capturedImage = savedImage;
        result = 'Uploading image...';
      });
      await _postData(live_photo: savedImage);
    } catch (e) {
      debugPrint('Error taking picture: $e');
      setState(() {
        result = 'Error taking picture: $e';
      });
    }
  }

  Future<void> _postData({required File live_photo}) async {
    try {
      final Uri apiUrl = Uri.parse('http://192.168.100.5:8000/analyze-image');
      var request = http.MultipartRequest('POST', apiUrl);
      request.files.add(
        await http.MultipartFile.fromPath('file', live_photo.path),
      );
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final descriptionText = data['description'] ?? 'Success';

        setState(() {
          result = descriptionText;
        });

        await _flutterTts.speak(descriptionText);
      } else {
        throw Exception(
          'Failed to post data ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      setState(() {
        result = 'Error: $e';
      });
      debugPrint('API error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Capture')),
      body: Column(
        children: [
          Expanded(
            child: capturedImage != null
                ? Image.file(capturedImage!, fit: BoxFit.contain)
                : FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return CameraPreview(_controller);
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12.0),
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              result.isEmpty ? 'Take a picture to analyze' : result,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (capturedImage != null)
                  ElevatedButton(
                    onPressed: () => setState(() {
                      capturedImage = null;
                      result = '';
                    }),
                    child: const Text('Retake'),
                  ),
                ElevatedButton.icon(
                  onPressed: capturedImage == null ? _takePicture : null,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
