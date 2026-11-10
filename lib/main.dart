import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

// ───────────────────────── helpers ─────────────────────────
const kExam = Color(0xFFFF6B8A);
const kAssign = Color(0xFF5CB8FF);
const kHabit = Color(0xFF4ADE80);
const kAccent = Color(0xFF8B5CF6);

String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
Color typeColor(String t) => t == 'Exam' ? kExam : kAssign;
bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color onSurf(BuildContext c) => Theme.of(c).colorScheme.onSurface;

String rel(DateTime d) {
  final diff = dateOnly(d).difference(dateOnly(DateTime.now())).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 0) return 'in $diff days';
  return '${-diff} days ago';
}

int streak(Habit h) {
  var d = DateTime.now();
  if (!h.days.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (h.days.contains(dayKey(d))) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

// ───────────────────────── models ─────────────────────────
class Assignment {
  String id, title, subject, type;
  DateTime date;
  bool done;
  Assignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.type,
    required this.date,
    this.done = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'type': type,
        'date': date.millisecondsSinceEpoch,
        'done': done,
      };
  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'],
        title: j['title'],
        subject: j['subject'] ?? '',
        type: j['type'] ?? 'Assignment',
        date: DateTime.fromMillisecondsSinceEpoch(j['date']),
        done: j['done'] ?? false,
      );
}

class Habit {
  String id, name, emoji;
  List<String> days;
  Habit({required this.id, required this.name, required this.emoji, List<String>? days})
      : days = days ?? [];
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'emoji': emoji, 'days': days};
  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'],
        name: j['name'],
        emoji: j['emoji'] ?? '✨',
        days: List<String>.from(j['days'] ?? []),
      );
}

// ───────────────────────── store ─────────────────────────
class Store extends ChangeNotifier {
  List<Assignment> assignments = [];
  List<Habit> habits = [];
  ThemeMode mode = ThemeMode.dark;
  Map<String, String> attendance = {};
  int thGreen = 85, thYellow = 75;
  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    try {
      final a = _p!.getString('assignments');
      final h = _p!.getString('habits');
      if (a != null) {
        assignments = (jsonDecode(a) as List)
            .map((e) => Assignment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (h != null) {
        habits = (jsonDecode(h) as List)
            .map((e) => Habit.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      mode = _p!.getString('mode') == 'light' ? ThemeMode.light : ThemeMode.dark;
      final att = _p!.getString('attendance');
      if (att != null) {
        attendance = Map<String, String>.from(jsonDecode(att) as Map);
      }
      thGreen = _p!.getInt('thGreen') ?? 85;
      thYellow = _p!.getInt('thYellow') ?? 75;
    } catch (_) {}
  }

  void _save() {
    _p?.setString('assignments', jsonEncode(assignments.map((e) => e.toJson()).toList()));
    _p?.setString('habits', jsonEncode(habits.map((e) => e.toJson()).toList()));
    _p?.setString('mode', mode == ThemeMode.light ? 'light' : 'dark');
    _p?.setString('attendance', jsonEncode(attendance));
    _p?.setInt('thGreen', thGreen);
    _p?.setInt('thYellow', thYellow);
    notifyListeners();
  }

  List<Assignment> get sorted =>
      [...assignments]..sort((a, b) => a.date.compareTo(b.date));

  List<Assignment> get upcoming {
    final t = dateOnly(DateTime.now());
    return sorted.where((a) => !a.done && !dateOnly(a.date).isBefore(t)).toList();
  }

  void setAttendance(DateTime d, String? status) {
    final k = dayKey(d);
    if (status == null) {
      attendance.remove(k);
    } else {
      attendance[k] = status;
    }
    _save();
  }

  void setThresholds(int green, int yellow) {
    thGreen = green;
    thYellow = yellow;
    _save();
  }

  void toggleMode() {
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _save();
  }

  void addAssignment(Assignment a) {
    assignments.add(a);
    _save();
  }

  void updateAssignment(Assignment a) => _save();

  void deleteAssignment(String id) {
    assignments.removeWhere((a) => a.id == id);
    _save();
  }

  void addHabit(Habit h) {
    habits.add(h);
    _save();
  }

  void deleteHabit(String id) {
    habits.removeWhere((h) => h.id == id);
    _save();
  }

  void toggleHabit(Habit h, DateTime day) {
    final k = dayKey(day);
    if (h.days.contains(k)) {
      h.days.remove(k);
    } else {
      h.days.add(k);
    }
    _save();
  }
}

final store = Store();

// ───────────────────────── app ─────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const StudyFlowApp());
}

ThemeData buildTheme(Brightness b) => ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(seedColor: kAccent, brightness: b),
      dialogBackgroundColor: b == Brightness.dark ? const Color(0xFF1B1636) : Colors.white,
    );

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) => MaterialApp(
        title: 'StudyFlow',
        debugShowCheckedModeBanner: false,
        themeMode: store.mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const Shell(),
      ),
    );
  }
}

// ───────────────────────── glass widgets ─────────────────────────
class Glass extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final double? opacity;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.onTap,
    this.opacity,
  });

  @override
  State<Glass> createState() => _GlassState();
}

class _GlassState extends State<Glass> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final d = isDark(context);
    final o = widget.opacity ?? (d ? 0.10 : 0.65);
    final r = BorderRadius.circular(widget.radius);
    final box = RepaintBoundary(
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withOpacity(o), Colors.white.withOpacity(o * 0.45)],
              ),
              borderRadius: r,
              border: Border.all(color: Colors.white.withOpacity(d ? 0.16 : 0.85)),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
    if (widget.onTap == null) return box;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: box,
      ),
    );
  }
}

class Orb extends StatelessWidget {
  final Color color;
  final double size;
  const Orb(this.color, this.size, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );
}

class Background extends StatelessWidget {
  const Background({super.key});
  @override
  Widget build(BuildContext context) {
    final d = isDark(context);
    return Stack(fit: StackFit.expand, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: d
                ? const [Color(0xFF0A0A18), Color(0xFF15102E), Color(0xFF0B1426)]
                : const [Color(0xFFEDE9FE), Color(0xFFE0ECFF), Color(0xFFFCE7F3)],
          ),
        ),
      ),
      Positioned(top: -90, left: -80, child: Orb(kAccent.withOpacity(d ? 0.55 : 0.40), 320)),
      Positioned(top: 260, right: -140, child: Orb(const Color(0xFF22D3EE).withOpacity(d ? 0.35 : 0.30), 360)),
      Positioned(bottom: -120, left: -60, child: Orb(const Color(0xFFEC4899).withOpacity(d ? 0.35 : 0.28), 340)),
    ]);
  }
}

class GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const GlassIconBtn(this.icon, this.onTap, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Glass(
        radius: 16,
        padding: const EdgeInsets.all(11),
        onTap: onTap,
        child: Icon(icon, size: 22, color: color ?? onSurf(context)),
      );
}

class PageHeader extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const PageHeader({super.key, required this.title, required this.subtitle, this.action});
  @override
  Widget build(BuildContext context) {
    final on = onSurf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: on)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 13.5, color: on.withOpacity(0.6))),
          ]),
        ),
        if (action != null) ...[action!, const SizedBox(width: 10)],
        GlassIconBtn(
          isDark(context) ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          store.toggleMode,
        ),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 20, 12),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: onSurf(context))),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class EmptyCard extends StatelessWidget {
  final String emoji, text;
  const EmptyCard(this.emoji, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Glass(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 8),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: onSurf(context).withOpacity(0.65))),
            ]),
          ),
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      );
}

Future<bool> confirmDelete(BuildContext c, String what) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (x) => AlertDialog(
      title: const Text('Delete?'),
      content: Text('Delete "$what"? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(x, true), child: const Text('Delete')),
      ],
    ),
  );
  return r ?? false;
}

InputDecoration deco(BuildContext c, String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: onSurf(c).withOpacity(0.07),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

// ───────────────────────── shell ─────────────────────────
final navIndex = ValueNotifier<int>(0);

class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context) {
    final d = isDark(context);
    const pages = [DashboardPage(), AssignmentsPage(), CalendarPage(), AttendancePage()];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (d ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Stack(children: [
        const Positioned.fill(child: Background()),
        Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: ValueListenableBuilder<int>(
              valueListenable: navIndex,
              builder: (c, idx, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(idx), child: pages[idx]),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: ValueListenableBuilder<int>(
                valueListenable: navIndex,
                builder: (c, idx, _) =>
                    NavBar(idx: idx, onTap: (i) => navIndex.value = i),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class NavBar extends StatelessWidget {
  final int idx;
  final ValueChanged<int> onTap;
  const NavBar({super.key, required this.idx, required this.onTap});
  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.dashboard_rounded,
      Icons.assignment_rounded,
      Icons.calendar_month_rounded,
      Icons.how_to_reg_rounded,
    ];
    const labels = ['Dashboard', 'Assignments', 'Calendar', 'Attendance'];
    final on = onSurf(context);
    return Glass(
      radius: 28,
      padding: const EdgeInsets.all(6),
      opacity: isDark(context) ? 0.12 : 0.75,
      child: Row(
        children: List.generate(4, (i) {
          final sel = i == idx;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? kAccent.withOpacity(0.28) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedScale(
                    scale: sel ? 1.15 : 1,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    child: Icon(icons[i], color: sel ? kAccent : on.withOpacity(0.55)),
                  ),
                  const SizedBox(height: 2),
                  Text(labels[i],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? kAccent : on.withOpacity(0.55),
                      )),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ───────────────────────── dashboard ─────────────────────────
class StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const StatCard(this.value, this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Glass(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: SizedBox(
          width: double.infinity,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: onSurf(context).withOpacity(0.65))),
          ]),
        ),
      );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final today = DateTime.now();
        final k = dayKey(today);
        final done = store.habits.where((h) => h.days.contains(k)).length;
        final up = store.upcoming;
        final exams = up.where((a) => a.type == 'Exam').length;
        return ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            PageHeader(
              title: 'Dashboard',
              subtitle: DateFormat('EEEE, d MMMM').format(today),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: StatCard('$done/${store.habits.length}', 'Habits today', kHabit)),
                const SizedBox(width: 10),
                Expanded(child: StatCard('$exams', 'Upcoming exams', kExam)),
                const SizedBox(width: 10),
                Expanded(child: StatCard('${up.length - exams}', 'Assignments due', kAssign)),
              ]),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: AttendanceSummary(),
            ),
            const SizedBox(height: 6),
            SectionTitle(
              'My Habits',
              trailing: GlassIconBtn(Icons.add_rounded, () => showHabitSheet(c)),
            ),
            if (store.habits.isEmpty)
              const EmptyCard('🌱', 'No habits yet.\nTap + to start tracking one.')
            else
              ...store.habits.map((h) => HabitTile(h: h)),
            const SectionTitle('Coming up'),
            if (up.isEmpty)
              const EmptyCard('🎉', 'Nothing due. Enjoy the free time!')
            else
              ...up.take(3).map((a) => AssignmentTile(a: a)),
          ],
        );
      },
    );
  }
}

class HabitTile extends StatelessWidget {
  final Habit h;
  const HabitTile({super.key, required this.h});
  @override
  Widget build(BuildContext context) {
    final on = onSurf(context);
    final today = DateTime.now();
    final done = h.days.contains(dayKey(today));
    final s = streak(h);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Glass(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kHabit.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(h.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: on)),
              const SizedBox(height: 3),
              Text(s > 0 ? '🔥 $s day streak' : 'Start your streak today',
                  style: TextStyle(fontSize: 12.5, color: on.withOpacity(0.6))),
              const SizedBox(height: 8),
              Row(
                children: List.generate(7, (i) {
                  final d = today.subtract(Duration(days: 6 - i));
                  final onDay = h.days.contains(dayKey(d));
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onDay ? kHabit : on.withOpacity(0.15),
                    ),
                  );
                }),
              ),
            ]),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, color: on.withOpacity(0.55)),
            onPressed: () async {
              if (await confirmDelete(context, h.name)) store.deleteHabit(h.id);
            },
          ),
          GestureDetector(
            onTap: () => store.toggleHabit(h, today),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? kHabit : Colors.transparent,
                border: Border.all(color: done ? kHabit : on.withOpacity(0.35), width: 2),
              ),
              child: Icon(Icons.check_rounded,
                  size: 22, color: done ? Colors.white : Colors.transparent),
            ),
          ),
        ]),
      ),
    );
  }
}

Future<void> showHabitSheet(BuildContext context) {
  final name = TextEditingController();
  String emoji = '💧';
  const options = ['💧', '📚', '🏃', '🧘', '💪', '🥗', '😴', '✍️', '🎧', '🧹', '💻', '🙏'];
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(ctx).viewInsets.bottom + 12),
        child: Glass(
          radius: 30,
          opacity: isDark(ctx) ? 0.18 : 0.9,
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New habit',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: onSurf(ctx))),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: deco(ctx, 'Habit name (e.g. Drink water)')),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((e) {
                final sel = e == emoji;
                return GestureDetector(
                  onTap: () => set(() => emoji = e),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? kAccent.withOpacity(0.3) : onSurf(ctx).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? kAccent : Colors.transparent, width: 2),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  store.addHabit(Habit(id: newId(), name: name.text.trim(), emoji: emoji));
                  Navigator.pop(ctx);
                },
                child: const Text('Add habit', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      );
    }),
  );
}

// ───────────────────────── assignments ─────────────────────────
class AssignmentTile extends StatelessWidget {
  final Assignment a;
  const AssignmentTile({super.key, required this.a});
  @override
  Widget build(BuildContext context) {
    final on = onSurf(context);
    final c = typeColor(a.type);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Glass(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        onTap: () => showAssignmentSheet(context, a: a),
        child: Row(children: [
          Container(
            width: 54,
            height: 58,
            decoration: BoxDecoration(
              color: c.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(DateFormat('d').format(a.date),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
              Text(DateFormat('MMM').format(a.date).toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: on.withOpacity(a.done ? 0.5 : 1),
                    decoration: a.done ? TextDecoration.lineThrough : null,
                  )),
              if (a.subject.isNotEmpty)
                Text(a.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: on.withOpacity(0.6))),
              const SizedBox(height: 6),
              Row(children: [
                Pill(a.type, c),
                const SizedBox(width: 8),
                Text(rel(a.date), style: TextStyle(fontSize: 12, color: on.withOpacity(0.6))),
              ]),
            ]),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                a.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: a.done ? kHabit : on.withOpacity(0.5),
              ),
              onPressed: () {
                a.done = !a.done;
                store.updateAssignment(a);
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline_rounded, color: on.withOpacity(0.55)),
              onPressed: () async {
                if (await confirmDelete(context, a.title)) store.deleteAssignment(a.id);
              },
            ),
          ]),
        ]),
      ),
    );
  }
}

Future<void> showAssignmentSheet(BuildContext context, {Assignment? a, DateTime? date}) {
  final title = TextEditingController(text: a?.title ?? '');
  final subject = TextEditingController(text: a?.subject ?? '');
  String type = a?.type ?? 'Assignment';
  DateTime d = a?.date ?? date ?? DateTime.now();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(ctx).viewInsets.bottom + 12),
        child: Glass(
          radius: 30,
          opacity: isDark(ctx) ? 0.18 : 0.9,
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a == null ? 'New entry' : 'Edit entry',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: onSurf(ctx))),
              const SizedBox(height: 16),
              TextField(controller: title, decoration: deco(ctx, 'Title (e.g. Maths Final)')),
              const SizedBox(height: 12),
              TextField(controller: subject, decoration: deco(ctx, 'Subject (optional)')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Assignment', label: Text('Assignment'), icon: Icon(Icons.edit_note_rounded)),
                    ButtonSegment(value: 'Exam', label: Text('Exam'), icon: Icon(Icons.school_rounded)),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => set(() => type = s.first),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.event_rounded),
                  label: Text(DateFormat('EEE, d MMM yyyy').format(d)),
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: d,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) set(() => d = p);
                  },
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    if (a == null) {
                      store.addAssignment(Assignment(
                        id: newId(),
                        title: title.text.trim(),
                        subject: subject.text.trim(),
                        type: type,
                        date: d,
                      ));
                    } else {
                      a.title = title.text.trim();
                      a.subject = subject.text.trim();
                      a.type = type;
                      a.date = d;
                      store.updateAssignment(a);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(a == null ? 'Add' : 'Save changes', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ]),
          ),
        ),
      );
    }),
  );
}

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});
  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final today = dateOnly(DateTime.now());
        final all = store.sorted.where((a) => filter == 'All' || a.type == filter).toList();
        final overdue = all.where((a) => !a.done && dateOnly(a.date).isBefore(today)).toList();
        final upcoming = all.where((a) => !a.done && !dateOnly(a.date).isBefore(today)).toList();
        final done = all.where((a) => a.done).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            PageHeader(
              title: 'Assignments',
              subtitle: 'Exams & deadlines by date',
              action: GlassIconBtn(Icons.add_rounded, () => showAssignmentSheet(c)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Wrap(
                spacing: 8,
                children: ['All', 'Exam', 'Assignment'].map((f) {
                  return ChoiceChip(
                    label: Text(f == 'All' ? 'All' : '${f}s'),
                    selected: filter == f,
                    selectedColor: kAccent.withOpacity(0.35),
                    onSelected: (_) => setState(() => filter = f),
                  );
                }).toList(),
              ),
            ),
            if (all.isEmpty) const EmptyCard('📚', 'Nothing here yet.\nTap + to add an exam or assignment.'),
            if (overdue.isNotEmpty) ...[
              const SectionTitle('Overdue'),
              ...overdue.map((a) => AssignmentTile(a: a)),
            ],
            if (upcoming.isNotEmpty) ...[
              const SectionTitle('Upcoming'),
              ...upcoming.map((a) => AssignmentTile(a: a)),
            ],
            if (done.isNotEmpty) ...[
              const SectionTitle('Completed'),
              ...done.map((a) => AssignmentTile(a: a)),
            ],
          ],
        );
      },
    );
  }
}

// ───────────────────────── calendar ─────────────────────────
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime focused = DateTime.now();
  DateTime selected = DateTime.now();

  Widget legend(String t, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(fontSize: 12.5, color: onSurf(context).withOpacity(0.7))),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final on = onSurf(c);
        final dayAssign = store.sorted.where((a) => sameDay(a.date, selected)).toList();
        final dayHabits = store.habits.where((h) => h.days.contains(dayKey(selected))).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            const PageHeader(title: 'Calendar', subtitle: 'Exams, assignments & habits'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                child: TableCalendar<Object>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: focused,
                  rowHeight: 48,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (d) => isSameDay(selected, d),
                  onDaySelected: (s, f) => setState(() {
                    selected = s;
                    focused = f;
                  }),
                  onPageChanged: (f) => focused = f,
                  eventLoader: (day) => <Object>[
                    ...store.assignments.where((a) => sameDay(a.date, day)),
                    ...store.habits.where((h) => h.days.contains(dayKey(day))),
                    if (store.attendance.containsKey(dayKey(day)))
                      AttMark(store.attendance[dayKey(day)]!),
                  ],
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(color: on, fontSize: 17, fontWeight: FontWeight.w700),
                    leftChevronIcon: Icon(Icons.chevron_left_rounded, color: on),
                    rightChevronIcon: Icon(Icons.chevron_right_rounded, color: on),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: on.withOpacity(0.6), fontSize: 12),
                    weekendStyle: TextStyle(color: on.withOpacity(0.6), fontSize: 12),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: TextStyle(color: on),
                    weekendTextStyle: TextStyle(color: on.withOpacity(0.85)),
                    todayTextStyle: TextStyle(color: on, fontWeight: FontWeight.w700),
                    todayDecoration: BoxDecoration(
                      color: kAccent.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle:
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    selectedDecoration:
                        const BoxDecoration(color: kAccent, shape: BoxShape.circle),
                  ),
                  calendarBuilders: CalendarBuilders<Object>(
                    markerBuilder: (ctx, day, events) {
                      if (events.isEmpty) return null;
                      final exam = events.any((e) => e is Assignment && e.type == 'Exam');
                      final asg = events.any((e) => e is Assignment && e.type != 'Exam');
                      final hab = events.any((e) => e is Habit);
                      Widget dot(Color col) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                          );
                      return Positioned(
                        bottom: 4,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (exam) dot(kExam),
                          if (asg) dot(kAssign),
                          if (hab) dot(kHabit),
                          ...events.whereType<AttMark>().map((m) => Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  color: attColor(m.status),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )),
                        ]),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 20, 0),
              child: Wrap(spacing: 18, children: [
                legend('Exam', kExam),
                legend('Assignment', kAssign),
                legend('Habit done', kHabit),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: kPresent,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Attendance',
                      style: TextStyle(fontSize: 12.5, color: onSurf(context).withOpacity(0.7))),
                ]),
              ]),
            ),
            const SizedBox(height: 6),
            SectionTitle(
              DateFormat('EEEE, d MMM').format(selected),
              trailing: GlassIconBtn(Icons.add_rounded, () => showAssignmentSheet(c, date: selected)),
            ),
            if (dayAssign.isEmpty && dayHabits.isEmpty)
              const EmptyCard('🗓️', 'Nothing scheduled for this day.'),
            CalendarAttendanceTile(day: selected),
            ...dayAssign.map((a) => AssignmentTile(a: a)),
            ...dayHabits.map((h) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Glass(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Text(h.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(h.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: on)),
                      ),
                      const Pill('Completed', kHabit),
                    ]),
                  ),
                )),
          ],
        );
      },
    );
  }
}


// ───────────────────────── attendance ─────────────────────────
const kPresent = Color(0xFF4ADE80);
const kSelfLeave = Color(0xFFFF6B8A);
const kHoliday = Color(0xFF9CA3AF);
const kWarn = Color(0xFFFACC15);
const kBad = Color(0xFFF87171);

class AttMark {
  final String status;
  const AttMark(this.status);
}

bool isWeekend(DateTime d) => d.weekday >= 6;
DateTime prevDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);
DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

Color attColor(String s) =>
    s == 'present' ? kPresent : (s == 'self' ? kSelfLeave : kHoliday);

String attLabel(String s) {
  if (s == 'present') return 'Present';
  if (s == 'self') return 'Self leave';
  if (s == 'public') return 'Public holiday';
  return 'College holiday';
}

IconData attIcon(String? s) {
  if (s == 'present') return Icons.check_circle_rounded;
  if (s == 'self') return Icons.person_off_rounded;
  if (s == null) return Icons.help_outline_rounded;
  return Icons.beach_access_rounded;
}

class AttStats {
  int present = 0, absent = 0, holidays = 0;
  int get working => present + absent;
  double? get pct => working == 0 ? null : present * 100 / working;
}

AttStats attStats({int? year, int? month}) {
  final st = AttStats();
  store.attendance.forEach((k, v) {
    final d = DateTime.parse(k);
    if (year != null && (d.year != year || d.month != month)) return;
    if (v == 'present') {
      st.present++;
    } else if (v == 'self') {
      st.absent++;
    } else {
      st.holidays++;
    }
  });
  return st;
}

Color pctColor(double? p) {
  if (p == null) return kHoliday;
  if (p >= store.thGreen) return kPresent;
  if (p >= store.thYellow) return kWarn;
  return kBad;
}

String pctLabel(double? p) {
  if (p == null) return 'No data yet';
  if (p >= store.thGreen) return 'On track';
  if (p >= store.thYellow) return 'Needs attention';
  return 'Low attendance';
}

/// Returns [current, longest] streak of attended days.
/// Weekends and holidays are skipped. Self leave and unrecorded weekdays break a streak.
List<int> attStreaks() {
  final a = store.attendance;
  if (a.isEmpty) return [0, 0];
  final today = dateOnly(DateTime.now());
  final first = a.keys.map(DateTime.parse).reduce((x, y) => x.isBefore(y) ? x : y);

  var cur = 0;
  var d = today;
  while (!d.isBefore(first)) {
    final v = a[dayKey(d)];
    if (v == 'present') {
      cur++;
    } else if (v == 'public' || v == 'college') {
    } else if (v == null && (isWeekend(d) || sameDay(d, today))) {
    } else {
      break;
    }
    d = prevDay(d);
  }

  var run = 0, best = 0;
  for (var x = first; !x.isAfter(today); x = nextDay(x)) {
    final v = a[dayKey(x)];
    if (v == 'present') {
      run++;
      if (run > best) best = run;
    } else if (v == 'public' || v == 'college') {
    } else if (v == null && (isWeekend(x) || sameDay(x, today))) {
    } else {
      run = 0;
    }
  }
  return [cur, best];
}

/// Present days divided by elapsed weekdays (holidays excluded). Unrecorded weekdays count against it.
double? attConsistency(int year, int month) {
  final today = dateOnly(DateTime.now());
  final dim = DateUtils.getDaysInMonth(year, month);
  var den = 0, att = 0;
  for (var i = 1; i <= dim; i++) {
    final d = DateTime(year, month, i);
    if (d.isAfter(today)) break;
    final v = store.attendance[dayKey(d)];
    if (sameDay(d, today) && v == null) continue;
    if (v == 'present') att++;
    if (!isWeekend(d) && v != 'public' && v != 'college') den++;
  }
  if (den == 0) return null;
  return (att * 100 / den).clamp(0, 100).toDouble();
}

Future<void> showAttendanceSheet(BuildContext context, DateTime day,
    {bool startAtReason = false}) {
  final isToday = sameDay(day, DateTime.now());
  var step = startAtReason ? 1 : 0;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final on = onSurf(ctx);
      final cur = store.attendance[dayKey(day)];
      void save(String? v) {
        store.setAttendance(day, v);
        Navigator.pop(ctx);
      }

      Widget reason(IconData icon, String t, String sub, String code, Color col) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Glass(
              radius: 18,
              padding: const EdgeInsets.all(14),
              onTap: () => save(code),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: col.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: col),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: on)),
                    Text(sub, style: TextStyle(fontSize: 12.5, color: on.withOpacity(0.6))),
                  ]),
                ),
              ]),
            ),
          );

      final question = isToday
          ? 'Are you going to college today?'
          : 'Were you at college on ${DateFormat('EEE, d MMM').format(day)}?';

      final stepZero = Column(
        key: const ValueKey(0),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(question, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: on)),
          if (cur != null) ...[
            const SizedBox(height: 6),
            Text('Currently: ${attLabel(cur)}',
                style: TextStyle(fontSize: 13, color: on.withOpacity(0.6))),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kPresent,
                  foregroundColor: const Color(0xFF0B1F12),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => save('present'),
                child: const Text('Yes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => set(() => step = 1),
                child: const Text('No', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          if (cur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => save(null),
                child: const Text('Clear record'),
              ),
            ),
        ],
      );

      final stepOne = Column(
        key: const ValueKey(1),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Why not?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: on)),
          const SizedBox(height: 14),
          reason(Icons.flag_rounded, 'Public holiday', 'Excluded from working days', 'public', kHoliday),
          reason(Icons.school_rounded, 'College holiday', 'Excluded from working days', 'college', kHoliday),
          reason(Icons.person_off_rounded, 'Self leave', 'Counts as absent', 'self', kSelfLeave),
          TextButton(
            onPressed: () => set(() => step = 0),
            child: const Text('Back'),
          ),
        ],
      );

      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(ctx).viewInsets.bottom + 12),
        child: Glass(
          radius: 30,
          opacity: isDark(ctx) ? 0.18 : 0.9,
          padding: const EdgeInsets.all(22),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: step == 0 ? stepZero : stepOne,
            ),
          ),
        ),
      );
    }),
  );
}

Future<void> showThresholdSheet(BuildContext context) {
  var g = store.thGreen;
  var y = store.thYellow;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final on = onSurf(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Glass(
          radius: 30,
          opacity: isDark(ctx) ? 0.18 : 0.9,
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Attendance thresholds',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: on)),
            const SizedBox(height: 4),
            Text('Choose where green and yellow start.',
                style: TextStyle(fontSize: 13, color: on.withOpacity(0.6))),
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.circle, size: 12, color: kPresent),
              const SizedBox(width: 8),
              Expanded(child: Text('Green from $g%', style: TextStyle(fontWeight: FontWeight.w600, color: on))),
            ]),
            Slider(
              value: g.toDouble(),
              min: 51,
              max: 100,
              divisions: 49,
              label: '$g%',
              onChanged: (v) => set(() {
                g = v.round();
                if (y >= g) y = g - 1;
              }),
              onChangeEnd: (_) => store.setThresholds(g, y),
            ),
            Row(children: [
              const Icon(Icons.circle, size: 12, color: kWarn),
              const SizedBox(width: 8),
              Expanded(child: Text('Yellow from $y%', style: TextStyle(fontWeight: FontWeight.w600, color: on))),
            ]),
            Slider(
              value: y.toDouble(),
              min: 50,
              max: 99,
              divisions: 49,
              label: '$y%',
              onChanged: (v) => set(() {
                y = v.round();
                if (g <= y) g = y + 1;
              }),
              onChangeEnd: (_) => store.setThresholds(g, y),
            ),
            Row(children: [
              const Icon(Icons.circle, size: 12, color: kBad),
              const SizedBox(width: 8),
              Text('Red below $y%', style: TextStyle(fontWeight: FontWeight.w600, color: on)),
            ]),
          ]),
        ),
      );
    }),
  );
}

class AttendanceSummary extends StatelessWidget {
  const AttendanceSummary({super.key});
  @override
  Widget build(BuildContext context) {
    final on = onSurf(context);
    final v = store.attendance[dayKey(DateTime.now())];
    final p = attStats().pct;
    final st = attStreaks();
    final col = v == null ? kAccent : attColor(v);
    return Glass(
      padding: const EdgeInsets.all(14),
      onTap: () => navIndex.value = 3,
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: col.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(attIcon(v), color: col),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Attendance today',
                style: TextStyle(fontSize: 12.5, color: on.withOpacity(0.6))),
            Text(v == null ? 'Not marked yet' : attLabel(v),
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: on)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(p == null ? '–' : '${p.round()}%',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: pctColor(p))),
          Text('overall', style: TextStyle(fontSize: 11, color: on.withOpacity(0.6))),
        ]),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${st[0]}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kWarn)),
          Text('streak', style: TextStyle(fontSize: 11, color: on.withOpacity(0.6))),
        ]),
      ]),
    );
  }
}

class CalendarAttendanceTile extends StatelessWidget {
  final DateTime day;
  const CalendarAttendanceTile({super.key, required this.day});
  @override
  Widget build(BuildContext context) {
    if (dateOnly(day).isAfter(dateOnly(DateTime.now()))) return const SizedBox.shrink();
    final on = onSurf(context);
    final v = store.attendance[dayKey(day)];
    final col = v == null ? kAccent : attColor(v);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Glass(
        padding: const EdgeInsets.all(14),
        onTap: () => showAttendanceSheet(context, day),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: col.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(attIcon(v), color: col),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Attendance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: on)),
              Text(v == null ? (isWeekend(day) ? 'Weekend, not recorded' : 'Not recorded. Tap to mark') : attLabel(v),
                  style: TextStyle(fontSize: 13, color: on.withOpacity(0.6))),
            ]),
          ),
          Icon(Icons.edit_rounded, size: 18, color: on.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

class MiniStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const MiniStat(this.value, this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: onSurf(context).withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: onSurf(context).withOpacity(0.65))),
          ),
        ]),
      );
}

class Heatmap extends StatelessWidget {
  final DateTime month, selected;
  final ValueChanged<DateTime> onSelect;
  const Heatmap({super.key, required this.month, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final on = onSurf(context);
    final today = dateOnly(DateTime.now());
    final dim = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    final cols = ((offset + dim) / 7).ceil();
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return LayoutBuilder(builder: (c, box) {
      const gap = 6.0;
      const lw = 22.0;
      final cell = ((box.maxWidth - lw - cols * gap) / cols).clamp(20.0, 42.0).toDouble();
      return Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(
          children: List.generate(
            7,
            (r) => SizedBox(
              width: lw,
              height: cell + gap,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(labels[r],
                    style: TextStyle(fontSize: 11, color: on.withOpacity(0.5))),
              ),
            ),
          ),
        ),
        ...List.generate(
          cols,
          (col) => Column(
            children: List.generate(7, (r) {
              final day = col * 7 + r - offset + 1;
              if (day < 1 || day > dim) {
                return SizedBox(width: cell + gap, height: cell + gap);
              }
              final date = DateTime(month.year, month.month, day);
              final v = store.attendance[dayKey(date)];
              final sel = sameDay(date, selected);
              final isToday = sameDay(date, today);
              final fill = sel
                  ? kAccent
                  : (v == null ? on.withOpacity(0.08) : attColor(v).withOpacity(0.9));
              final txt = sel
                  ? Colors.white
                  : (v == null ? on.withOpacity(0.55) : const Color(0xFF10101C));
              return SizedBox(
                width: cell + gap,
                height: cell + gap,
                child: Padding(
                  padding: const EdgeInsets.only(right: gap, bottom: gap),
                  child: GestureDetector(
                    onTap: () => onSelect(date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      transformAlignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(sel ? 1.1 : 1.0, sel ? 1.1 : 1.0, 1.0),
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(cell * 0.28),
                        border: isToday && !sel
                            ? Border.all(color: on.withOpacity(0.7), width: 1.5)
                            : null,
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        Text('$day',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w600, color: txt)),
                        if (sel && v != null)
                          Positioned(
                            bottom: 3,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: attColor(v),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ]);
    });
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = dateOnly(DateTime.now());

  void goMonth(int delta) {
    final m = DateTime(month.year, month.month + delta);
    final now = DateTime.now();
    setState(() {
      month = m;
      selected = (m.year == now.year && m.month == now.month) ? dateOnly(now) : m;
    });
  }

  Widget legendItem(String t, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(fontSize: 12, color: onSurf(context).withOpacity(0.7))),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final on = onSurf(c);
        final today = dateOnly(DateTime.now());
        final todayV = store.attendance[dayKey(today)];
        final ms = attStats(year: month.year, month: month.month);
        final all = attStats();
        final p = ms.pct;
        final pc = pctColor(p);
        final st = attStreaks();
        final cons = attConsistency(month.year, month.month);
        final selV = store.attendance[dayKey(selected)];
        final future = selected.isAfter(today);

        return ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            PageHeader(
              title: 'Attendance',
              subtitle: 'Track your college days',
              action: GlassIconBtn(Icons.tune_rounded, () => showThresholdSheet(c)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Glass(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: todayV == null
                      ? Column(
                          key: const ValueKey('ask'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Are you going to college today?',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: on)),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kPresent,
                                    foregroundColor: const Color(0xFF0B1F12),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: () => store.setAttendance(today, 'present'),
                                  child: const Text('Yes',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: () =>
                                      showAttendanceSheet(c, today, startAtReason: true),
                                  child: const Text('No',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ]),
                          ],
                        )
                      : Row(key: const ValueKey('done'), children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: attColor(todayV).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(attIcon(todayV), color: attColor(todayV)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Today',
                                  style: TextStyle(fontSize: 12.5, color: on.withOpacity(0.6))),
                              Text(attLabel(todayV),
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: on)),
                            ]),
                          ),
                          TextButton(
                            onPressed: () => showAttendanceSheet(c, today),
                            child: const Text('Edit'),
                          ),
                        ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(children: [
                  Row(children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded, color: on),
                      onPressed: () => goMonth(-1),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          DateFormat('MMMM yyyy').format(month),
                          key: ValueKey(month),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: on),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, color: on),
                      onPressed: () => goMonth(1),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: KeyedSubtree(
                      key: ValueKey(month),
                      child: Heatmap(
                        month: month,
                        selected: selected,
                        onSelect: (d) => setState(() => selected = d),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(spacing: 14, runSpacing: 6, children: [
                    legendItem('Present', kPresent),
                    legendItem('Self leave', kSelfLeave),
                    legendItem('Holiday', kHoliday),
                    legendItem('Unrecorded', on.withOpacity(0.15)),
                    legendItem('Selected', kAccent),
                  ]),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Glass(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: (selV == null ? kAccent : attColor(selV)).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(attIcon(selV), color: selV == null ? kAccent : attColor(selV)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(DateFormat('EEEE, d MMM').format(selected),
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: on)),
                      Text(
                        future
                            ? 'Upcoming date'
                            : (selV == null
                                ? (isWeekend(selected) ? 'Weekend, not recorded' : 'Not recorded')
                                : attLabel(selV)),
                        style: TextStyle(fontSize: 13, color: on.withOpacity(0.6)),
                      ),
                    ]),
                  ),
                  if (!future)
                    FilledButton.tonal(
                      onPressed: () => showAttendanceSheet(c, selected),
                      child: Text(selV == null ? 'Mark' : 'Edit'),
                    ),
                ]),
              ),
            ),
            SectionTitle('Analytics'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Glass(
                child: Column(children: [
                  Row(children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(alignment: Alignment.center, children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: (p ?? 0) / 100),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (ctx, v, _) => SizedBox(
                            width: 96,
                            height: 96,
                            child: CircularProgressIndicator(
                              value: v,
                              strokeWidth: 9,
                              strokeCap: StrokeCap.round,
                              backgroundColor: on.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(pc),
                            ),
                          ),
                        ),
                        Text(p == null ? '–' : '${p.round()}%',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: on)),
                      ]),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(DateFormat('MMMM').format(month),
                            style: TextStyle(fontSize: 13, color: on.withOpacity(0.6))),
                        const SizedBox(height: 4),
                        Pill(pctLabel(p), pc),
                        const SizedBox(height: 8),
                        Text(
                          all.pct == null ? 'Overall: no data' : 'Overall: ${all.pct!.round()}%',
                          style: TextStyle(fontSize: 13, color: on.withOpacity(0.7)),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: MiniStat('${ms.working}', 'Working days', kAssign)),
                    const SizedBox(width: 10),
                    Expanded(child: MiniStat('${ms.present}', 'Present', kPresent)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: MiniStat('${ms.absent}', 'Absent', kSelfLeave)),
                    const SizedBox(width: 10),
                    Expanded(child: MiniStat('${ms.holidays}', 'Holidays', kHoliday)),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    'Present days divided by working days. Holidays and unrecorded days are left out.',
                    style: TextStyle(fontSize: 11.5, color: on.withOpacity(0.55)),
                  ),
                ]),
              ),
            ),
            SectionTitle('Streaks'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Glass(
                child: Row(children: [
                  Expanded(child: _streakCell(Icons.local_fire_department_rounded, '${st[0]}', 'Current', kWarn)),
                  Expanded(child: _streakCell(Icons.emoji_events_rounded, '${st[1]}', 'Longest', kAccent)),
                  Expanded(
                    child: _streakCell(Icons.insights_rounded,
                        cons == null ? '–' : '${cons.round()}%', 'Consistency', kPresent),
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _streakCell(IconData icon, String value, String label, Color color) {
    final on = onSurf(context);
    return Column(children: [
      Icon(icon, color: color, size: 26),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: on)),
      Text(label, style: TextStyle(fontSize: 12, color: on.withOpacity(0.6))),
    ]);
  }
}
