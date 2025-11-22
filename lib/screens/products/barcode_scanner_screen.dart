// lib/screens/products/barcode_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/products_provider.dart';
import '../../models/diary_entry.dart';
import '../../models/product.dart';
import '../../services/barcode_sheets_service.dart';
import 'scanned_product_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final MealType mealType;

  const BarcodeScannerScreen({
    super.key,
    required this.mealType,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  String? _lastScannedCode;
  bool _isSearching = false;
  String _searchStatus = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Avoid processing the same code multiple times
    if (_lastScannedCode == code) return;
    _lastScannedCode = code;

    setState(() {
      _isProcessing = true;
      _isSearching = true;
      _searchStatus = 'Поиск продукта...';
    });

    // Stop scanning while processing
    await _controller.stop();

    try {
      // 1. First search in local Google Sheets barcode database
      setState(() => _searchStatus = 'Поиск в базе штрихкодов...');

      final barcodeSheetsService = BarcodeSheetsService();
      Product? foundProduct = await barcodeSheetsService.findProductByBarcode(code);
      String source = 'Google Sheets Barcode DB';
      bool isPheCalculated = false;

      // Check if Phe was calculated
      if (foundProduct != null && foundProduct.pheMeasuredPer100g == null) {
        isPheCalculated = true;
      }

      // 2. If not found, search in Firestore (local user database)
      if (foundProduct == null) {
        setState(() => _searchStatus = 'Поиск в локальной базе...');

        final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
        final result = await productsProvider.findProductByBarcode(code);

        if (result.product.name.isNotEmpty) {
          foundProduct = result.product;
          source = result.source;
          isPheCalculated = result.product.pheMeasuredPer100g == null;
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ScannedProductScreen(
              barcode: code,
              product: foundProduct,
              source: source,
              mealType: widget.mealType,
              isPheCalculated: isPheCalculated,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSearching = false;
          _lastScannedCode = null;
        });

        await _controller.start();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка поиска: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать штрихкод'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchState = state.torchState;
              return IconButton(
                icon: switch (torchState) {
                  TorchState.off => const Icon(Icons.flash_off),
                  TorchState.on => const Icon(Icons.flash_on, color: Colors.yellow),
                  TorchState.auto => const Icon(Icons.flash_auto),
                  TorchState.unavailable => const Icon(Icons.no_flash),
                },
                onPressed: () => _controller.toggleTorch(),
                tooltip: 'Вспышка',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Сменить камеру',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),

          // Scan overlay
          Center(
            child: Container(
              width: 280,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isSearching ? Colors.orange : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSearching) ...[
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _searchStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Наведите камеру на штрихкод',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Добавление в: ${widget.mealType.displayName}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
