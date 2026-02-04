import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AppColors.primaryBlack : AppColors.accentGray,
        foregroundColor: isPrimary ? AppColors.pureWhite : AppColors.primaryBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final String productName;
  final double price;
  final String? imageUrl;
  final bool isFeaturedIxon;
  final bool isFeatured;
  final bool isPromo;
  final double promoDiscountPercent;
  final bool isPackage;
  final int quantity;

  const ProductCard({
    super.key,
    required this.productName,
    required this.price,
    this.imageUrl,
    this.isFeaturedIxon = false,
    this.isFeatured = false,
    this.isPromo = false,
    this.promoDiscountPercent = 0,
    this.isPackage = false,
    this.quantity = 0,
  });

  double get finalPrice {
    if (isPromo && promoDiscountPercent > 0) {
      return price * (1 - promoDiscountPercent / 100);
    }
    return price;
  }

  String _formatPrice(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}';
  }

  @override
  Widget build(BuildContext context) {
    bool isSpecial = isPromo || isFeatured || isPackage;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isSpecial 
          ? Border.all(color: isPromo ? Colors.red.withOpacity(0.3) : Colors.amber.withOpacity(0.3), width: 1.5)
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          if (isSpecial)
            BoxShadow(
              color: (isPromo ? Colors.red : Colors.amber).withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                    ),
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                // Product Content
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 36, // Ensure title has consistent space
                          child: Text(
                            productName.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPromo && promoDiscountPercent > 0) ...[
                              Text(
                                _formatPrice(price),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _formatPrice(finalPrice),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFEF4444),
                                  fontSize: 15,
                                ),
                              ),
                            ] else ...[
                              Text(
                                _formatPrice(price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981), // Back to emerald green for normal price
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Badges Overlay (Glassmorphism inspired)
            Positioned(
              top: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isPromo)
                    _buildGlassBadge('${promoDiscountPercent.toStringAsFixed(0)}% OFF', const Color(0xFFEF4444)),
                  if (isFeaturedIxon)
                    _buildGlassBadge('IXON', const Color(0xFFF59E0B)),
                  if (isFeatured)
                    _buildGlassBadge('FAVORIT', const Color(0xFF3B82F6)),
                  if (isPackage)
                    _buildGlassBadge('PAKET', const Color(0xFF8B5CF6)),
                ],
              ),
            ),

            // Promo Sparkle
            if (isPromo)
              Positioned(
                bottom: 80,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flash_on, color: Colors.white, size: 14),
                ),
              ),

            // Quantity Indicator
            if (quantity > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$quantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

            // Subtle Plus Button (Interactive Hint)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
                child: const Icon(Icons.add, size: 18, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 40,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

