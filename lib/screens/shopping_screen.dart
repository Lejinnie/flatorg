import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_theme.dart';
import '../constants/strings.dart';
import '../models/issue.dart';
import '../providers/flat_provider.dart';
import '../repositories/shopping_repository.dart';
import '../router/app_router.dart';
import '../widgets/shopping_item_tile.dart';
import 'main_scaffold.dart';

/// Shopping list screen.
///
/// Shows unbought items above a divider and bought (greyed, struck-through)
/// items below.  New items can be added via an inline text field.
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) => const MainScaffold(
    currentIndex: 1,
    child: _ShoppingBody(),
  );
}

class _ShoppingBody extends StatefulWidget {
  const _ShoppingBody();

  @override
  State<_ShoppingBody> createState() => _ShoppingBodyState();
}

class _ShoppingBodyState extends State<_ShoppingBody> {
  var _showAddField = false;
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem(String flatId, String addedByUid) async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _showAddField = false);
      return;
    }

    final itemId = FirebaseFirestore.instance
        .collection('flats')
        .doc(flatId)
        .collection('shoppingItems')
        .doc()
        .id;

    await ShoppingRepository().addShoppingItem(
      flatId,
      ShoppingItem(
        id: itemId,
        text: text,
        addedBy: addedByUid,
        isBought: false,
        boughtAt: null,
      ),
    );

    _addCtrl.clear();
    setState(() => _showAddField = false);
  }

  @override
  Widget build(BuildContext context) {
    final flatProvider  = context.watch<FlatProvider>();
    final flatId        = flatProvider.flatId;
    final currentUid    = flatProvider.currentPerson?.uid ?? '';
    final cleanupHours  = flatProvider.flat?.shoppingCleanupHours ?? 6;
    final theme         = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(headingShopping),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: headingSettings,
            onPressed: () => context.push(routeSettings),
          ),
        ],
      ),
      body: StreamBuilder<List<ShoppingItem>>(
        stream: ShoppingRepository().watchShoppingItems(flatId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all     = snap.data ?? [];
          final unbought = all.where((i) => !i.isBought).toList();
          final bought   = all.where((i) => i.isBought).toList();

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
            children: [
              // Inline add field (appears at top when active).
              if (_showAddField)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingXs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: hintShoppingItem,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addItem(flatId, currentUid),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: AppTheme.featureColor),
                        onPressed: () => _addItem(flatId, currentUid),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.grayMid),
                        onPressed: () {
                          _addCtrl.clear();
                          setState(() => _showAddField = false);
                        },
                      ),
                    ],
                  ),
                ),

              // Unbought items.
              ...unbought.map(
                (item) => ShoppingItemTile(
                  item: item,
                  onToggleBought: () => ShoppingRepository().markBought(flatId, item.id),
                ),
              ),

              // Add Item button.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingSm,
                ),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text(buttonAddItem),
                  onPressed: () => setState(() => _showAddField = true),
                ),
              ),

              // Divider + "Disappears after Xh" label.
              if (bought.isNotEmpty) ...[
                const Divider(height: AppTheme.spacingLg),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingXs,
                  ),
                  child: Text(
                    shoppingDisappearsAfter.replaceFirst(
                      '{hours}',
                      '$cleanupHours',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.grayMid,
                    ),
                  ),
                ),
                ...bought.map(
                  (item) => ShoppingItemTile(
                    item: item,
                    onToggleBought: () => ShoppingRepository().markUnbought(flatId, item.id),
                  ),
                ),
              ],
            ],
            ), // ListView
          ); // RefreshIndicator
        },
      ),
    );
  }
}
