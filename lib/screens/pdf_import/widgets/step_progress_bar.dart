import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';

/// Clean, human-designed 5-step progress indicator for the PDF import wizard.
class StepProgressBar extends StatelessWidget {
  final int currentStep; // 1 to 5
  final List<String> stepTitles = const [
    'Upload',
    'Instructions',
    'Processing',
    'Review',
    'Complete',
  ];

  const StepProgressBar({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.outline.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppDimensions.borderRadiusMd,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step $currentStep of 5',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
              Text(
                stepTitles[currentStep - 1],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final stepNum = index + 1;
              final isCompleted = stepNum < currentStep;
              final isCurrent = stepNum == currentStep;

              return Expanded(
                child: Row(
                  children: [
                    // Node
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? primary
                            : (isCurrent ? primary : theme.colorScheme.surface),
                        border: Border.all(
                          color: (isCompleted || isCurrent) ? primary : inactiveColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                            : Text(
                                '$stepNum',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isCurrent
                                      ? Colors.white
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                      ),
                    ),
                    // Connector Line (except for last node)
                    if (index < 4)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: stepNum < currentStep ? primary : inactiveColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
