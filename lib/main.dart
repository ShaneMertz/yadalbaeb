import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const KanbanApp());

const bg = Color(0xFF0E1621);
const panel = Color(0xFF17212B);
const cardBg = Color(0xFF202B38);
const accent = Color(0xFF2B5278);
const muted = Color(0xFF8FA3B8);

class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kanban CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: Color(0xFF5FA8E8), surface: panel),
        useMaterial3: true,
      ),
      home: const BoardPage(),
    );
  }
}

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
      'поставщик' => const Color(0xFF3A8BC0),
      'команда' => const Color(0xFF3AA06A),
      'оплата' => const Color(0xFFA08A3A),
      'срочно' => const Color(0xFFC0503A),
      _ => muted,
    };

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  List<Task> tasks = [];
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    _file = File('${dir.path}/board.json');
    if (await _file!.exists()) {
      final data = jsonDecode(await _file!.readAsString()) as List;
      setState(() => tasks = data.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList());
    } else {
      setState(() => tasks = [
            Task(id: '1', title: 'Декларация OLMASELIK', note: 'Лена обещала до 15.11', column: 'wait', tag: 'поставщик'),
            Task(id: '2', title: 'Оплатить счёт ФФ', column: 'todo', tag: 'оплата'),
            Task(id: '3', title: 'Обложка B — проверить CTR', column: 'doing', tag: 'команда'),
            Task(id: '4', title: 'Поставка WB', column: 'done'),
          ]);
      _save();
    }
  }

  Future<void> _save() async {
    await _file?.writeAsString(jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  void _move(Task t, String col) {
    setState(() => t.column = col);
    _save();
  }

  void _delete(Task t) {
    setState(() => tasks.remove(t));
    _save();
  }

  Future<void> _edit({Task? task, String column = 'todo'}) async {
    final title = TextEditingController(text: task?.title ?? '');
    final note = TextEditingController(text: task?.note ?? '');
    var tag = task?.tag ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: panel,
          title: Text(task == null ? 'Новая задача' : 'Задача'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Название')),
              const SizedBox(height: 8),
              TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Заметка')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: tags
                    .map((t) => ChoiceChip(
                          label: Text(t.isEmpty ? 'без метки' : t),
                          selected: tag == t,
                          onSelected: (_) => setD(() => tag = t),
                        ))
                    .toList(),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    setState(() {
      if (task == null) {
        tasks.add(Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title.text.trim(),
          note: note.text.trim(),
          column: column,
          tag: tag,
        ));
      } else {
        task
          ..title = title.text.trim()
          ..note = note.text.trim()
          ..tag = tag;
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: panel,
        title: const Text('Kanban CRM', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Задача'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columns.map((c) => Expanded(child: _column(c))).toList(),
        ),
      ),
    );
  }

  Widget _column(ColumnDef c) {
    final items = tasks.where((t) => t.column == c.id).toList();
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => d.data.column != c.id,
      onAcceptWithDetails: (d) => _move(d.data, c.id),
      builder: (ctx, cand, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cand.isNotEmpty ? accent.withValues(alpha: 0.35) : panel,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(width: 6),
            Text('${items.length}', style: const TextStyle(color: muted)),
            const Spacer(),
            IconButton(
              tooltip: 'Добавить',
              icon: const Icon(Icons.add, size: 18, color: muted),
              onPressed: () => _edit(column: c.id),
            ),
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(children: items.map(_card).toList()),
          ),
        ]),
      ),
    );
  }

  Widget _card(Task t) {
    final body = _CardBody(task: t);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Draggable<Task>(
        data: t,
        feedback: Material(color: Colors.transparent, child: SizedBox(width: 260, child: Opacity(opacity: 0.9, child: body))),
        childWhenDragging: Opacity(opacity: 0.3, child: body),
        child: GestureDetector(
          onTap: () => _edit(task: t),
          onSecondaryTapDown: (d) async {
            final r = await showMenu<String>(
              context: context,
              position: RelativeRect.fromLTRB(d.globalPosition.dx, d.globalPosition.dy, d.globalPosition.dx, d.globalPosition.dy),
              items: const [PopupMenuItem(value: 'del', child: Text('Удалить'))],
            );
            if (r == 'del') _delete(t);
          },
          child: MouseRegion(cursor: SystemMouseCursors.grab, child: body),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2B3A4B))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
        if (task.note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(task.note, style: const TextStyle(color: muted, fontSize: 12)),
        ],
        if (task.tag.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: tagColor(task.tag).withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
            child: Text(task.tag, style: TextStyle(color: tagColor(task.tag), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }
}
