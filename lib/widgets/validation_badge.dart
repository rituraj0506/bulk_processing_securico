import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/panel_record_model.dart';
import '../theme/app_colors.dart';

class ValidationBadgeCard extends StatelessWidget {
  final ValidationResult result;

  const ValidationBadgeCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = result.isValid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isValid ? AppColors.successBg : AppColors.errorBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isValid ? AppColors.success : AppColors.error,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isValid ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isValid ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isValid ? 'VALID FILE FORMAT' : 'INVALID FILE FORMAT',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isValid ? AppColors.success : AppColors.error,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isValid ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isValid ? 'Success' : 'Validation Error',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isValid ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Required Fields Status List
          Text(
            'Required Columns Verification (${result.foundFields.length}/${result.requiredFields.length} Required):',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.requiredFields.map((field) {
              final isFound = result.foundFields.contains(field);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFound ? AppColors.success : AppColors.error,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFound ? Icons.check_circle : Icons.error_outline_rounded,
                      size: 14,
                      color: isFound ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      field,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isFound ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          // Display Error Message if file is invalid (Missing fields or Duplicate data)
          if (!isValid && result.errorMessage != null && result.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.errorMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isValid) ...[
            const SizedBox(height: 12),
            Text(
              '🎉 All required fields present & all records unique! ${result.totalRows} panel records loaded.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ]
        ],
      ),
    );
  }
}
