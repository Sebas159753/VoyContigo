import 'package:flutter/material.dart';
import 'package:voycontigo/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingDialog extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const RatingDialog({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _selectedStars = 5;
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);
    
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.targetUserId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        
        if (!snapshot.exists) {
          throw Exception("User not found");
        }
        
        final data = snapshot.data()!;
        final currentRating = (data['rating'] as num?)?.toDouble() ?? 5.0;
        final totalRatings = (data['totalRatings'] as num?)?.toInt() ?? 1;
        
        final newTotal = totalRatings + 1;
        final newRating = ((currentRating * totalRatings) + _selectedStars) / newTotal;
        
        transaction.update(docRef, {
          'rating': newRating,
          'totalRatings': newTotal,
        });
      });
      
      if (mounted) {
        Navigator.pop(context, true); // true indicates successful rating
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar la calificación: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.amber, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Viaje Finalizado!',
              style: AppTheme.bodyFont(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Cómo calificarías a ${widget.targetUserName}?',
              style: AppTheme.bodyFont(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  iconSize: 40,
                  icon: Icon(
                    index < _selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: index < _selectedStars ? Colors.amber : Colors.grey[300],
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedStars = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Enviar Calificación',
                        style: AppTheme.bodyFont(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (!_isSubmitting)
              TextButton(
                onPressed: () => Navigator.pop(context, false), // skip rating
                child: Text(
                  'Omitir por ahora',
                  style: AppTheme.bodyFont(color: Colors.black54, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
