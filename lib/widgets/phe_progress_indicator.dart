import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class PheProgressIndicator extends StatelessWidget {
  const PheProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final progress = userProvider.progressPercentage;
        final current = userProvider.currentPheIntake;
        final limit = userProvider.userProfile?.dailyTolerancePhe ?? 0;
        final remaining = userProvider.remainingPhe;

        Color progressColor;
        if (progress < 0.5) {
          progressColor = Colors.green;
        } else if (progress < 0.8) {
          progressColor = Colors.orange;
        } else {
          progressColor = Colors.red;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Circular Progress
                SizedBox(
                  height: 180,
                  width: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 180,
                        width: 180,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${current.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: progressColor,
                                ),
                          ),
                          Text(
                            'из ${limit.toStringAsFixed(0)} мг',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Remaining Phe
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        remaining > 0 ? Icons.check_circle_outline : Icons.warning_amber,
                        color: progressColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        remaining > 0
                            ? 'Осталось: ${remaining.toStringAsFixed(0)} мг'
                            : 'Лимит превышен на ${(-remaining).toStringAsFixed(0)} мг',
                        style: TextStyle(
                          color: progressColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}