import 'package:flutter/material.dart';
import '../../foundation/spacing.dart';
import '../../foundation/radius.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// 植物カードコンポーネント
class PlantCard extends StatelessWidget {
  /// 植物の画像URL
  final String? imageUrl;

  /// 植物の名前
  final String name;

  /// 植物の説明
  final String? description;

  /// カードタップ時のコールバック
  final VoidCallback? onTap;

  /// お気に入り状態
  final bool isFavorite;

  /// お気に入りボタンのコールバック
  final VoidCallback? onFavoriteToggle;

  /// カスタムの高さ
  final double? height;

  /// 画像の高さ
  final double imageHeight;

  const PlantCard({
    Key? key,
    this.imageUrl,
    required this.name,
    this.description,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.height,
    this.imageHeight = 180.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Stack(
      children: [
        Container(
          height: imageHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.grey200,
          ),
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholder();
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildPlaceholder();
                  },
                )
              : _buildPlaceholder(),
        ),
        if (onFavoriteToggle != null)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: _buildFavoriteButton(),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.photo,
        size: 64,
        color: AppColors.grey400,
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? AppColors.error : AppColors.grey600,
        ),
        iconSize: 24,
        onPressed: onFavoriteToggle,
        padding: EdgeInsets.all(AppSpacing.sm),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: AppTextStyles.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (description != null && description!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Text(
                  description!,
                  style: AppTextStyles.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
