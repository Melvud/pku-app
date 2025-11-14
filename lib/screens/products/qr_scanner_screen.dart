// lib/screens/products/qr_scanner_screen.dart (обновленная версия)
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/products_provider.dart';
import '../../models/product.dart';
import '../../models/diary_entry.dart';
import '../../services/multi_source_barcode_service.dart';
import 'edit_product_portion_screen.dart';
import 'quick_add_product_screen.dart';

class QRScannerScreen extends StatefulWidget {
  final MealType mealType;

  const QRScannerScreen({
    super.key,
    required this.mealType,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final String? code = barcode.rawValue;

    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      await cameraController.stop();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Поиск продукта...'),
                  const SizedBox(height: 8),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Проверяем все доступные базы данных',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final productsProvider = Provider.of<ProductsProvider>(context, listen: false);
      final result = await productsProvider.findProductByBarcode(code);

      if (mounted) {
        Navigator.pop(context);
      }

      if (result.product.name.isNotEmpty && result.hasNutritionData) {
        // Найден продукт с полными данными
        if (mounted) {
          if (result.product.id.isEmpty) {
            await productsProvider.saveProductWithBarcode(result.product);
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Найдено в: ${result.source}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EditProductPortionScreen(
                product: result.product,
                mealType: widget.mealType,
              ),
            ),
          );
        }
      } else {
        // Продукт не найден или найдено только название - быстрый ввод
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QuickAddProductScreen(
                barcode: code,
                productName: result.product.name,
                mealType: widget.mealType,
                source: result.source,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error processing barcode: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
        await cameraController.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать штрих-код'),
        actions: [
          IconButton(
            icon: Icon(
              cameraController.torchEnabled == TorchState.on
                  ? Icons.flash_on
                  : Icons.flash_off,
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Наведите камеру на штрих-код продукта',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Поиск в локальной базе, Open Food Facts и других источниках',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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