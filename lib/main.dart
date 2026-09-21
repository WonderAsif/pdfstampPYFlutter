import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Dart PDF Stamper',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PdfStamperHome(),
    );
  }
}

class PdfStamperHome extends StatefulWidget {
  const PdfStamperHome({super.key});
  @override
  State<PdfStamperHome> createState() => _PdfStamperHomeState();
}

class _PdfStamperHomeState extends State<PdfStamperHome> {
  String _status = 'Ready to process';
  bool _isProcessing = false;
  
  // 1. Add a controller to capture the password
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _processPdfNatively() async {
    setState(() {
      _status = 'Selecting file...';
      _isProcessing = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'],
      );

      if (result == null) {
        setState(() { _status = 'Cancelled'; _isProcessing = false; });
        return;
      }

      setState(() => _status = 'Processing PDF locally...');

      File file = File(result.files.single.path!);
      List<int> bytes = await file.readAsBytes();
      
      PdfDocument document;
      
      // 2. Safely attempt to open the PDF with or without the password
      try {
        if (_passwordController.text.isNotEmpty) {
          document = PdfDocument(inputBytes: bytes, password: _passwordController.text);
        } else {
          document = PdfDocument(inputBytes: bytes);
        }
      } catch (e) {
        if (e.toString().contains('encrypted') || e.toString().contains('password')) {
           setState(() {
             _status = '✗ Error: PDF is password protected. Enter password below.';
             _isProcessing = false;
           });
           return;
        }
        rethrow;
      }

      bool modified = false;

      for (int i = 0; i < document.form.fields.count; i++) {
        PdfField field = document.form.fields[i];
        if (field is PdfSignatureField) {
          Rect bounds = field.bounds;
          PdfPage page = field.page!;
          double w = bounds.width;
          double h = bounds.height;
          
          double p1x = bounds.left + (w * 0.38);
          double p1y = bounds.top + (h * 0.45);
          double p2x = bounds.left + (w * 0.48);
          double p2y = bounds.top + (h * 0.22);
          double p3x = bounds.left + (w * 0.64);
          double p3y = bounds.top + (h * 0.76);

          double greenW = w * 0.05;
          double outlineW = greenW + (w * 0.015);
          double shadowX = w * 0.015;
          double shadowY = h * 0.025;

          PdfGraphics graphics = page.graphics;
          graphics.drawRectangle(bounds: bounds, brush: PdfBrushes.white);

          PdfPen outlinePen = PdfPen(PdfColor(0, 0, 0), width: outlineW)..lineJoin = PdfLineJoin.miter;
          PdfPath outlinePath = PdfPath()
            ..addLine(Offset(p1x + shadowX, p1y - shadowY), Offset(p2x + shadowX, p2y - shadowY))
            ..addLine(Offset(p2x + shadowX, p2y - shadowY), Offset(p3x + shadowX, p3y - shadowY));
          graphics.drawPath(outlinePath, pen: outlinePen);

          PdfPen greenPen = PdfPen(PdfColor(0, 153, 38), width: greenW)..lineJoin = PdfLineJoin.miter;
          PdfPath greenPath = PdfPath()
            ..addLine(Offset(p1x, p1y), Offset(p2x, p2y))
            ..addLine(Offset(p2x, p2y), Offset(p3x, p3y));
          graphics.drawPath(greenPath, pen: greenPen);

          modified = true;
        }
      }

      if (!modified) throw Exception("No signature field found to replace.");

      List<int> outBytes = await document.save();
      document.dispose();

      Directory? outputDir = await getDownloadsDirectory(); 
      String fileName = file.path.split('/').last.replaceAll('.pdf', '_stamped.pdf');
      String outputPath = '${outputDir!.path}/$fileName';
      
      await File(outputPath).writeAsBytes(outBytes);

      setState(() {
        _status = '✓ Success!\n\nSaved to: $outputPath';
        _isProcessing = false;
      });

    } catch (e) {
      setState(() { _status = '✗ Error: $e'; _isProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exact Image Replica Stamper')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              
              // 3. Add the UI TextField for the password
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'PDF Password (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              ElevatedButton(
                onPressed: _isProcessing ? null : _processPdfNatively,
                child: _isProcessing 
                  ? const CircularProgressIndicator() 
                  : const Text('Select & Stamp PDF'), //
              ),
            ],
          ),
        ),
      ),
    );
  }
}
