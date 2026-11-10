import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const KanbanApp());

// ---------- Палитра ----------
const bg = Color(0xFF0E1621);
const panel = Color(0xFF151F2A);
const cardBg = Color(0xFF1E2935);
const cardHover = Color(0xFF243140);
const border = Color(0xFF2B3A4B);
const accent = Color(0xFF5FA8E8);
const muted = Color(0xFF8FA3B8);
const text = Color(0xFFE8EDF2);

const fast = Duration(milliseconds: 160);
const mid = Duration(milliseconds: 260);
const curve = Curves.easeOutCubic;

class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: accent, surface: panel, onSurface: text),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: accent, width: 1.5)),
        labelStyle: const TextStyle(color: muted),
      ),
    );
    return MaterialApp(
      title: 'Kanban CRM',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(bodyColor: text, displayColor: text, fontFamily: 'Inter'),
      ),
      scrollBehavior: const _SmoothScroll(),
      home: const BoardPage(),
    );
  }
}

class _SmoothScroll extends MaterialScrollBehavior {
  const _SmoothScroll();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

// ---------- Модель ----------
class Task {
  Task({required this.id, required this.title, this.note = '', required this.column, this.tag = ''});
  final String id;
  String title;
  String note;
  String column;
  String tag;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'note': note, 'column': column, 'tag': tag};
  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        note: (j['note'] ?? '') as String,
        column: j['column'] as String,
        tag: (j['tag'] ?? '') as String,
      );
}

class ColumnDef {
  const ColumnDef(this.id, this.title, this.color);
  final String id;
  final String title;
  final Color color;
}

const columns = [
  ColumnDef('todo', 'Нужно сделать', Color(0xFF8CC4FF)),
  ColumnDef('wait', 'Ждём ответа', Color(0xFFFFCF6B)),
  ColumnDef('doing', 'В работе', Color(0xFFB794F6)),
  ColumnDef('done', 'Готово', Color(0xFF6BE0A8)),
];

const tags = ['', 'поставщик', 'команда', 'оплата', 'срочно'];

Color tagColor(String t) => switch (t) {
      'поставщик' => const Color(0xFF5AA9E6),
      'команда' => const Color(0xFF4CC38A),
      'оплата' => const Color(0xFFE0B252),
      'срочно' => const Color(0xFFF07167),
      _ => muted,
    };

// ---------- Доска ----------
class BoardPage extends StatefulWidget {
  const BoardPage({super.key});
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  List<Task> tasks = [];
  final Set<String> _leaving = {}; // удаляются — анимация исчезновения
  SharedPreferences? _prefs;
  static const _key = 'board_v1';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    final list = raw != null
        ? (jsonDecode(raw) as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList()
        : [
            Task(id: '1', title: 'Документы от поставщика', note: 'Обещали до пятницы', column: 'wait', tag: 'поставщик'),
            Task(id: '2', title: 'Оплатить счёт склада', column: 'todo', tag: 'оплата'),
            Task(id: '3', title: 'Проверить новую обложку', column: 'doing', tag: 'команда'),
            Task(id: '4', title: 'Отгрузка на маркетплейс', column: 'done'),
          ];
    setState(() {
      tasks = list;
      _loaded = true;
    });
    if (raw == null) _save();
  }

  Future<void> _save() async {
    await _prefs?.setString(_key, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  /// Переместить задачу в колонку [col], встав перед задачей [beforeId] (или в конец).
  void _move(Task t, String col, {String? beforeId}) {
    if (t.id == beforeId) return;
    setState(() {
      tasks.remove(t);
      t.column = col;
      final idx = beforeId == null ? -1 : tasks.indexWhere((x) => x.id == beforeId);
      if (idx < 0) {
        tasks.add(t);
      } else {
        tasks.insert(idx, t);
      }
    });
    HapticFeedback.selectionClick();
    _save();
  }

  void _delete(Task t) {
    setState(() => _leaving.add(t.id));
    Future.delayed(mid, () {
      if (!mounted) return;
      setState(() {
        tasks.remove(t);
        _leaving.remove(t.id);
      });
      _save();
    });
  }

  Future<void> _edit({Task? task, String column = 'todo'}) async {
    final res = await showGeneralDialog<_EditResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: mid,
      pageBuilder: (_, __, ___) => _EditDialog(task: task),
      transitionBuilder: (ctx, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(c), child: child),
        );
      },
    );
    if (res == null) return;
    if (res.delete && task != null) {
      _delete(task);
      return;
    }
    if (res.title.isEmpty) return;
    setState(() {
      if (task == null) {
        final t = Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: res.title,
          note: res.note,
          column: column,
          tag: res.tag,
        );
        tasks.add(t);
      } else {
        task
          ..title = res.title
          ..note = res.note
          ..tag = res.tag;
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () => _edit(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => _edit(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(children: [
              _header(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (var i = 0; i < columns.length; i++) Expanded(child: _column(columns[i], i))],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final total = tasks.length;
    final done = tasks.where((t) => t.column == 'done').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      child: Row(children: [
        const Text('Kanban CRM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        const SizedBox(width: 14),
        _Pill(text: '$done из $total готово'),
        const Spacer(),
        _HoverButton(
          onTap: () => _edit(),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text('Задача', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            SizedBox(width: 8),
            Text('⌘N', style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF))),
          ]),
        ),
      ]),
    );
  }

  Widget _column(ColumnDef c, int index) {
    final items = tasks.where((t) => t.column == c.id).toList();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _loaded ? 1 : 0),
      duration: Duration(milliseconds: 380 + index * 70),
      curve: curve,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
      child: DragTarget<Task>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => _move(d.data, c.id),
        builder: (ctx, cand, _) {
          final hot = cand.isNotEmpty;
          return AnimatedContainer(
            duration: fast,
            curve: curve,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            decoration: BoxDecoration(
              color: hot ? Color.lerp(panel, c.color, 0.08) : panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hot ? c.color.withValues(alpha: 0.6) : Colors.transparent, width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                  const SizedBox(width: 9),
                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: fast,
                    transitionBuilder: (w, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: w)),
                    child: _Pill(key: ValueKey(items.length), text: '${items.length}'),
                  ),
                  const Spacer(),
                  _IconHover(icon: Icons.add_rounded, onTap: () => _edit(column: c.id)),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final t in items) _cardSlot(t, c),
                    _EndSlot(onAccept: (task) => _move(task, c.id), color: c.color),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _cardSlot(Task t, ColumnDef c) {
    final leaving = _leaving.contains(t.id);
    Widget card = DragTarget<Task>(
      onWillAcceptWithDetails: (d) => d.data.id != t.id,
      onAcceptWithDetails: (d) => _move(d.data, c.id, beforeId: t.id),
      builder: (ctx, cand, _) {
        final hovering = cand.isNotEmpty;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Анимированный зазор: показывает, куда упадёт карточка
          AnimatedContainer(
            duration: fast,
            curve: curve,
            height: hovering ? 58 : 0,
            margin: EdgeInsets.only(bottom: hovering ? 8 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: c.color.withValues(alpha: 0.10),
              border: Border.all(color: c.color.withValues(alpha: hovering ? 0.5 : 0)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DraggableCard(task: t, onTap: () => _edit(task: t), onDelete: () => _delete(t)),
          ),
        ]);
      },
    );

    card = AnimatedOpacity(
      duration: mid,
      curve: curve,
      opacity: leaving ? 0 : 1,
      child: AnimatedScale(duration: mid, curve: curve, scale: leaving ? 0.92 : 1, child: card),
    );
    card = _Appear(child: card);
    return KeyedSubtree(key: ValueKey(t.id), child: card);
  }
}

/// Появление: один раз при монтировании (новая карточка, загрузка, переезд в другую колонку).
class _Appear extends StatefulWidget {
  const _Appear({required this.child});
  final Widget child;
  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: SizeTransition(
          sizeFactor: _a,
          axisAlignment: -1,
          child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(_a), child: widget.child),
        ),
      );
}

// ---------- Карточка ----------
class _DraggableCard extends StatelessWidget {
  const _DraggableCard({required this.task, required this.onTap, required this.onDelete});
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final body = _CardBody(task: task, onTap: onTap, onDelete: onDelete);
      return Draggable<Task>(
        data: task,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: _DragFeedback(width: box.maxWidth, task: task),
        childWhenDragging: Opacity(opacity: 0.25, child: body),
        child: body,
      );
    });
  }
}

class _DragFeedback extends StatefulWidget {
  const _DragFeedback({required this.width, required this.task});
  final double width;
  final Task task;
  @override
  State<_DragFeedback> createState() => _DragFeedbackState();
}

class _DragFeedbackState extends State<_DragFeedback> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: fast)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Transform.translate(
          offset: Offset(-widget.width / 2, -24),
          child: Transform.rotate(
            angle: -2.5 * math.pi / 180 * v,
            child: Transform.scale(scale: 1 + 0.04 * v, child: child),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 28, offset: const Offset(0, 14))],
          ),
          child: _CardContent(task: widget.task, hover: true),
        ),
      ),
    );
  }
}

class _CardBody extends StatefulWidget {
  const _CardBody({required this.task, required this.onTap, required this.onDelete});
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  @override
  State<_CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends State<_CardBody> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          onSecondaryTapDown: (d) async {
            final r = await showMenu<String>(
              context: context,
              color: cardHover,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              position: RelativeRect.fromLTRB(d.globalPosition.dx, d.globalPosition.dy, d.globalPosition.dx, d.globalPosition.dy),
              items: const [
                PopupMenuItem(value: 'edit', child: Text('Изменить')),
                PopupMenuItem(value: 'del', child: Text('Удалить', style: TextStyle(color: Color(0xFFF07167)))),
              ],
            );
            if (r == 'del') widget.onDelete();
            if (r == 'edit') widget.onTap();
          },
          child: AnimatedScale(
            scale: _down ? 0.98 : (_hover ? 1.012 : 1.0),
            duration: fast,
            curve: curve,
            child: AnimatedContainer(
              duration: fast,
              curve: curve,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _hover
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 6))]
                    : const [],
              ),
              child: _CardContent(task: widget.task, hover: _hover),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.task, required this.hover});
  final Task task;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: fast,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: hover ? cardHover : cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hover ? const Color(0xFF3A4D62) : border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.3, color: text)),
        if (task.note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(task.note, style: const TextStyle(color: muted, fontSize: 12.5, height: 1.35)),
        ],
        if (task.tag.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Tag(task.tag),
        ],
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.tag);
  final String tag;
  @override
  Widget build(BuildContext context) {
    final c = tagColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
      child: Text(tag, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

/// Пустая зона в конце колонки: бросить карточку в конец.
class _EndSlot extends StatelessWidget {
  const _EndSlot({required this.onAccept, required this.color});
  final void Function(Task) onAccept;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (_, cand, __) => AnimatedContainer(
        duration: fast,
        curve: curve,
        height: cand.isNotEmpty ? 58 : 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: cand.isNotEmpty ? 0.10 : 0),
          border: Border.all(color: color.withValues(alpha: cand.isNotEmpty ? 0.5 : 0)),
        ),
      ),
    );
  }
}

// ---------- Мелкие элементы ----------
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFF223042), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()])),
      );
}

class _HoverButton extends StatefulWidget {
  const _HoverButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _h = false, _d = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _d = true),
          onTapUp: (_) => setState(() => _d = false),
          onTapCancel: () => setState(() => _d = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _d ? 0.96 : 1,
            duration: fast,
            child: AnimatedContainer(
              duration: fast,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _h ? const Color(0xFF6DB4F0) : accent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _h ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))] : const [],
              ),
              child: widget.child,
            ),
          ),
        ),
      );
}

class _IconHover extends StatefulWidget {
  const _IconHover({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_IconHover> createState() => _IconHoverState();
}

class _IconHoverState extends State<_IconHover> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: fast,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: _h ? const Color(0xFF223042) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: AnimatedRotation(
              turns: _h ? 0.25 : 0,
              duration: mid,
              curve: curve,
              child: Icon(widget.icon, size: 18, color: _h ? text : muted),
            ),
          ),
        ),
      );
}

// ---------- Диалог ----------
class _EditResult {
  _EditResult(this.title, this.note, this.tag, {this.delete = false});
  final String title, note, tag;
  final bool delete;
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({this.task});
  final Task? task;
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _note = TextEditingController(text: widget.task?.note ?? '');
  late String _tag = widget.task?.tag ?? '';

  void _submit() => Navigator.pop(context, _EditResult(_title.text.trim(), _note.text.trim(), _tag));

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        elevation: 24,
        shadowColor: Colors.black,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
            const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
          },
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.task == null ? 'Новая задача' : 'Задача', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(controller: _title, autofocus: true, onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Название')),
              const SizedBox(height: 12),
              TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Заметка')),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in tags)
                  GestureDetector(
                    onTap: () => setState(() => _tag = t),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: fast,
                        curve: curve,
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: _tag == t ? tagColor(t).withValues(alpha: 0.22) : bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _tag == t ? tagColor(t) : border),
                        ),
                        child: Text(t.isEmpty ? 'без метки' : t,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _tag == t ? tagColor(t) : muted)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                if (widget.task != null)
                  TextButton(
                    onPressed: () => Navigator.pop(context, _EditResult('', '', '', delete: true)),
                    child: const Text('Удалить', style: TextStyle(color: Color(0xFFF07167))),
                  ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена', style: TextStyle(color: muted))),
                const SizedBox(width: 8),
                _HoverButton(onTap: _submit, child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
