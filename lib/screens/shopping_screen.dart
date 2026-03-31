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
/// Shows a permanent input field at the top, then unbought items (drag-to-reorder)
/// above a divider, and bought (greyed, struck-through) items below.
/// Long-pressing any item enters deletion mode where tapping deletes the item.
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
  var _deletionMode = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _enterDeletionMode() => setState(() => _deletionMode = true);
  void _exitDeletionMode() => setState(() => _deletionMode = false);

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
        // Use timestamp millis so new items always sort after any reordered item
        // (which gets compact indices 0, 1, 2… after a drag operation).
        order: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    _addCtrl.clear();
  }

  void _onReorder(String flatId, List<ShoppingItem> unbought, int oldIndex, int newIndex) {
    // Flutter's ReorderableListView fires newIndex already past the removed item
    // position; adjust before splicing.
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final reordered = List<ShoppingItem>.from(unbought);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    unawaited(ShoppingRepository().updateItemOrders(flatId, reordered));
  }

  @override
  Widget build(BuildContext context) {
    final flatProvider = context.watch<FlatProvider>();
    final flatId = flatProvider.flatId;
    final currentUid = flatProvider.currentPerson?.uid ?? '';
    final cleanupHours = flatProvider.flat?.shoppingCleanupHours ?? 6;
    final theme = Theme.of(context);

    return PopScope(
      // Intercept Android back button while in deletion mode.
      canPop: !_deletionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _exitDeletionMode();
        }
      },
      child: Scaffold(
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
            // ── Permanent input field ───────────────────────────────────────
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
                      onSubmitted: (_) async {
                        // Pass empty list as fallback; stream not available here.
                        // Actual unbought count comes from the StreamBuilder below
                        // but for ordering we re-read from stream on submit.
                        await _addItem(flatId, currentUid);
                      },
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

            // ── Deletion mode bar ───────────────────────────────────────────
            if (_deletionMode)
              _DeletionBar(onGoBack: _exitDeletionMode),

            // ── Item list ───────────────────────────────────────────────────
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
                        // Unbought items — reorderable in normal mode.
                        if (unbought.isNotEmpty)
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            // Disable drag in deletion mode.
                            onReorder: _deletionMode
                                ? (_, __) {}
                                : (old, nw) => _onReorder(flatId, unbought, old, nw),
                            children: [
                              for (var i = 0; i < unbought.length; i++)
                                ShoppingItemTile(
                                  key: ValueKey(unbought[i].id),
                                  item: unbought[i],
                                  isDeletionMode: _deletionMode,
                                  onToggleBought: () =>
                                      ShoppingRepository().markBought(flatId, unbought[i].id),
                                  onDelete: () =>
                                      ShoppingRepository().deleteItem(flatId, unbought[i].id),
                                  onLongPress: _enterDeletionMode,
                                  dragHandle: _deletionMode
                                      ? null
                                      : ReorderableDragStartListener(
                                          index: i,
                                          child: const Padding(
                                            padding: EdgeInsets.all(AppTheme.spacingMd),
                                            child: Icon(Icons.drag_handle, color: AppTheme.grayMid),
                                          ),
                                        ),
                                ),
                            ],
                          ),

                        // Bought items section.
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
                              key: ValueKey(item.id),
                              item: item,
                              isDeletionMode: _deletionMode,
                              onToggleBought: () =>
                                  ShoppingRepository().markUnbought(flatId, item.id),
                              onDelete: () =>
                                  ShoppingRepository().deleteItem(flatId, item.id),
                              onLongPress: _enterDeletionMode,
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
      ),
    );
  }
}

/// Bar shown below the AppBar when deletion mode is active.
/// Provides a "Go Back" (← arrow) to exit deletion mode.
class _DeletionBar extends StatelessWidget {
  const _DeletionBar({required this.onGoBack});

  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXs,
          vertical: AppTheme.spacingXs,
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onGoBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text(buttonGoBack),
            ),
          ],
        ),
      );
}
