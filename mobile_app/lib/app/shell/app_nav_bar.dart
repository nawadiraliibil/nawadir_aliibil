import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shapes.dart';

/// وجهة في كبسولة التنقل.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// وجهات التنقل الأربع بترتيب التصميم.
const navDestinations = [
  NavDestination(
    label: 'الرئيسية',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  NavDestination(
    label: 'المفضلة',
    icon: Icons.favorite_border,
    selectedIcon: Icons.favorite,
  ),
  NavDestination(
    label: 'الرسائل',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
  ),
  NavDestination(
    label: 'حسابي',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

/// شريط التنقل العائم: كبسولة بأربع وجهات وبجانبها زر «إعلان» المستقل.
///
/// عنصر واحد يبنيه الهيكل مرة واحدة، فلا يتغير عرض الكبسولة ولا موضع الزر
/// عند تبديل التبويب (ملاحظة MOBILE-NAV-STABLE-20261121).
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onPostAd,
    this.badges = const {},
  });

  /// ارتفاع الشريط دون الهوامش.
  static const double height = 68;

  /// المسافة بين الشريط وحافة الشاشة السفلية.
  static const double bottomGap = 14;

  /// أقصى عرض للشريط، كما في المعرض.
  static const double maxWidth = 402;

  /// المساحة التي يحجبها الشريط من أسفل الشاشة، دون هامش النظام الآمن.
  static const double occupiedHeight = height + bottomGap + 12;

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onPostAd;

  /// عدّاد على وجهة (فهرسها ← العدد)، مثل غير المقروء في «الرسائل».
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppShapes.nav),
                  ),
                  border: Border.all(color: c.line),
                  boxShadow: c.floatingShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      for (var i = 0; i < navDestinations.length; i++)
                        Expanded(
                          child: _NavItem(
                            destination: navDestinations[i],
                            selected: i == currentIndex,
                            badge: badges[i] ?? 0,
                            onTap: () => onDestinationSelected(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _PostAdButton(onTap: onPostAd),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final NavDestination destination;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.gold : c.muted;
    const radius = BorderRadius.all(Radius.circular(24));

    // `excludeSemantics` يحذف إجراء الضغط الذي يعلنه `InkWell`، فيُمرر هنا
    // صراحة ليتمكن قارئ الشاشة من تفعيل الوجهة.
    return Semantics(
      selected: selected,
      button: true,
      label: badge > 0
          ? '${destination.label}، $badge غير مقروءة'
          : destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.tintGold : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 99 ? '99+' : '$badge'),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              // يثبت حجم التسمية كي لا يكسر تكبير النص ارتفاع الكبسولة؛
              // التسمية كاملة متاحة لقارئ الشاشة.
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                textScaler: TextScaler.noScaling,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostAdButton extends StatelessWidget {
  const _PostAdButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const radius = BorderRadius.all(Radius.circular(AppShapes.nav));

    return Semantics(
      button: true,
      label: 'أضف إعلان',
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: c.floatingShadow,
        ),
        child: Material(
          color: c.button,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 22, color: c.buttonText),
                  const SizedBox(height: 2),
                  Text(
                    'إعلان',
                    maxLines: 1,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: c.buttonText,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
