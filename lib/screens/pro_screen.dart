import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/court_themes.dart';

/// Hoop Shoot PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final HoopAudio audio;
  final HoopSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('PRO unlocked — enjoy everything!',
                  style: HoopType.body(15)),
          backgroundColor: const Color(0xFF241407),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: HoopType.body(15)),
        backgroundColor: const Color(0xFF241407),
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
    final s = widget.settings;
    final store = widget.store;
    return Scaffold(
      backgroundColor: t.wall,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            widget.audio.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('Hoop Shoot PRO', style: HoopType.headline(22)),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (_, __) => SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Column(
            children: [
              _comparisonCard(t, s),
              const SizedBox(height: 16),
              _buyCard(t, s, store),
              const SizedBox(height: 16),
              _tipsCard(t, store),
              const SizedBox(height: 16),
              if (s.isPro)
                Text('You are PRO — thanks for the love! 🏀',
                    style: HoopType.body(14)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- comparison

  Widget _comparisonCard(CourtThemeDef t, HoopSettings s) {
    const rows = [
      ['Shot Clock, Streak, Shootout', true, true],
      ['Endless mode', false, true],
      ['Rookie + Street difficulty', true, true],
      ['All-Star difficulty', false, true],
      ['5 court themes', true, true],
      ['All 13 courts + creator', false, true],
      ['4 ball styles', true, true],
      ['All 8 ball styles', false, true],
      ['3 hoop styles', true, true],
      ['All 8 hoop styles', false, true],
      ['Renameable players, music, SFX', true, true],
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE8A820), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                  width: 56,
                  child: Text('FREE',
                      textAlign: TextAlign.center,
                      style: HoopType.label(12))),
              SizedBox(
                  width: 56,
                  child: Text('PRO',
                      textAlign: TextAlign.center,
                      style: HoopType.label(12,
                          color: const Color(0xFFE8A820)))),
            ],
          ),
          const Divider(color: Colors.white24),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                      child: Text(r[0] as String,
                          style: HoopType.body(13))),
                  SizedBox(
                      width: 56,
                      child: _check(r[1] as bool)),
                  SizedBox(
                      width: 56,
                      child: _check(r[2] as bool,
                          gold: true)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _check(bool yes, {bool gold = false}) {
    return Icon(
      yes ? Icons.check_circle : Icons.remove_circle_outline,
      color: yes
          ? (gold
              ? const Color(0xFFE8A820)
              : Colors.white.withValues(alpha: 0.85))
          : Colors.white.withValues(alpha: 0.25),
      size: 20,
    );
  }

  // ------------------------------------------------------------------ buy

  Widget _buyCard(
      CourtThemeDef t, HoopSettings s, StoreService store) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Unlock PRO',
              textAlign: TextAlign.center,
              style: HoopType.headline(19)),
          const SizedBox(height: 6),
          Text(
            'One-time purchase. Yours forever, on every device.',
            textAlign: TextAlign.center,
            style: HoopType.body(12,
                color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          if (s.isPro)
            _note('PRO is active on this device. 🏀')
          else if (!store.storeReady)
            _note(
                'Store setup is still in progress — the buy button appears automatically once the products are live. ${store.error ?? ''}')
          else if (store.proProduct != null)
            ElevatedButton(
              onPressed: store.purchaseInProgress.value
                  ? null
                  : () {
                      widget.audio.click();
                      store.buyPro();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8A820),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Get PRO — ${store.proProduct!.price}',
                style: HoopType.headline(16,
                    color: Colors.black),
              ),
            )
          else
            _note('PRO product not found in the store yet.'),
          if (store.purchaseInProgress.value)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Center(child: CircularProgressIndicator()),
            ),
          ValueListenableBuilder<String?>(
            valueListenable: store.purchaseError,
            builder: (_, err, __) => err == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(err,
                        textAlign: TextAlign.center,
                        style: HoopType.body(13,
                            color: const Color(0xFFF08080))),
                  ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              widget.audio.click();
              store.restore();
            },
            child: Text('Restore purchases',
                style: HoopType.body(14,
                    color: Colors.white.withValues(alpha: 0.8))),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- tip jar

  Widget _tipsCard(CourtThemeDef t, StoreService store) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('Tip jar ☕🍫',
              style: HoopType.headline(18)),
          const SizedBox(height: 6),
          Text(
            'Hoop Shoot is made by one indie dev. Tips keep the sneakers laced!',
            textAlign: TextAlign.center,
            style: HoopType.body(12,
                color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            _note(
                'Tips appear here once the store products are live. ${store.error ?? ''}')
          else
            Row(
              children: [
                Expanded(
                    child: _tipButton(
                        store.coffeeProduct, '☕', store)),
                const SizedBox(width: 10),
                Expanded(
                    child: _tipButton(
                        store.chocolateProduct, '🍫', store)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tipButton(
      ProductDetails? p, String emoji, StoreService store) {
    if (p == null) {
      return _note('Not available yet');
    }
    return ElevatedButton(
      onPressed: store.purchaseInProgress.value
          ? null
          : () {
              widget.audio.click();
              store.buyTip(p);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      child: Text('$emoji ${p.price}',
          style: HoopType.body(14)),
    );
  }

  Widget _note(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: HoopType.body(13,
          color: Colors.white.withValues(alpha: 0.75)),
    );
  }
}
