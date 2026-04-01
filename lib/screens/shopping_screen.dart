import 'dart:async';

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
/// Shows a permanent input field at the top, then unbought items
/// (drag-to-reorder, newest first) above a divider, and bought
/// (greyed, struck-through) items below.
/// Swipe any item left to delete it.
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
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem(String flatId, String addedByUid) async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) {
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
        // Timestamp millis guarantees the new item sorts above all reordered
        // items (which receive compact descending indices after a drag).
        order: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    _addCtrl.clear();
  }

  void _onReorder(String flatId, List<ShoppingItem> unbought, int oldIndex, int newIndex) {
    // Flutter fires newIndex past the removed slot; adjust before splicing.
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final reordered = List<ShoppingItem>.from(unbought);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    unawaited(ShoppingRepository().updateItemOrders(flatId, reordered));
  }

  /// Red slide-left background shown while the user drags an item toward dismissal.
  Widget _dismissBackground() => Container(
        color: AppTheme.destructiveRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacingMd),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    final flatProvider = context.watch<FlatProvider>();
    final flatId = flatProvider.flatId;
    final currentUid = flatProvider.currentPerson?.uid ?? '';
    final cleanupHours = flatProvider.flat?.shoppingCleanupHours ?? 6;
    final theme = Theme.of(context);

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
      body: Column(
        children: [
          // ── Permanent input field ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMd,
              AppTheme.spacingSm,
              AppTheme.spacingXs,
              AppTheme.spacingXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addCtrl,
                    decoration: const InputDecoration(
                      hintText: hintShoppingItem,
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(flatId, currentUid),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.featureColor,
                  tooltip: buttonAddItem,
                  onPressed: () => _addItem(flatId, currentUid),
                ),
              ],
            ),
          ),

          // ── Item list ─────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<ShoppingItem>>(
              stream: ShoppingRepository().watchShoppingItems(flatId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data ?? [];
                final unbought = all.where((i) => !i.isBought).toList();
                final bought = all.where((i) => i.isBought).toList();

                return RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                    children: [
                      // Unbought items — drag to reorder, swipe left to delete.
                      if (unbought.isNotEmpty)
                        ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          onReorder: (old, nw) =>
                              _onReorder(flatId, unbought, old, nw),
                          children: [
                            for (var i = 0; i < unbought.length; i++)
                              Dismissible(
                                key: ValueKey(unbought[i].id),
                                direction: DismissDirection.endToStart,
                                background: _dismissBackground(),
                                onDismissed: (_) => ShoppingRepository()
                                    .deleteItem(flatId, unbought[i].id),
                                child: ShoppingItemTile(
                                  item: unbought[i],
                                  onToggleBought: () => ShoppingRepository()
                                      .markBought(flatId, unbought[i].id),
                                  dragHandle: ReorderableDragStartListener(
                                    index: i,
                                    child: const Padding(
                                      padding: EdgeInsets.all(AppTheme.spacingMd),
                                      child: Icon(
                                        Icons.drag_handle,
                                        color: AppTheme.grayMid,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                      // Bought (struck-through) section.
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
                          (item) => Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: _dismissBackground(),
                            onDismissed: (_) =>
                                ShoppingRepository().deleteItem(flatId, item.id),
                            child: ShoppingItemTile(
                              item: item,
                              onToggleBought: () =>
                                  ShoppingRepository().markUnbought(flatId, item.id),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
