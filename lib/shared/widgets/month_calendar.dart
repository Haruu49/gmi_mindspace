import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';

/// Lightweight month grid with event markers and day selection.
/// Used for booking dates and the well-being activities calendar.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.markedDays = const {},
    this.firstDay,
    this.lastDay,
    this.onlyMarkedSelectable = false,
  });

  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  /// Days (date-only) that have events / open slots.
  final Set<DateTime> markedDays;
  final DateTime? firstDay;
  final DateTime? lastDay;
  final bool onlyMarkedSelectable;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month = DateTime(
    (widget.selected ?? DateTime.now()).year,
    (widget.selected ?? DateTime.now()).month,
  );

  bool _canGo(int delta) {
    final target = DateTime(_month.year, _month.month + delta);
    if (delta < 0 && widget.firstDay != null) {
      return !target.isBefore(DateTime(widget.firstDay!.year, widget.firstDay!.month));
    }
    if (delta > 0 && widget.lastDay != null) {
      return !target.isAfter(DateTime(widget.lastDay!.year, widget.lastDay!.month));
    }
    return true;
  }

  bool _enabled(DateTime d) {
    if (widget.firstDay != null && d.isBefore(DateUtils.dateOnly(widget.firstDay!))) return false;
    if (widget.lastDay != null && d.isAfter(DateUtils.dateOnly(widget.lastDay!))) return false;
    if (widget.onlyMarkedSelectable && !widget.markedDays.contains(d)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final leading = DateTime(_month.year, _month.month).weekday - 1; // Monday first
    final today = DateUtils.dateOnly(DateTime.now());
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: _canGo(-1) ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(_month),
                style: context.text.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: _canGo(1) ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Center(
                  child: ExcludeSemantics(child: Text(w.substring(0, 1), style: context.text.labelSmall)),
                ),
              ),
          ],
        ),
        AppSpacing.gapXxs,
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(builder: (context) {
                    final index = r * 7 + c - leading;
                    if (index < 0 || index >= daysInMonth) return const SizedBox(height: 44);
                    final day = DateTime(_month.year, _month.month, index + 1);
                    final selected = widget.selected != null && DateUtils.isSameDay(day, widget.selected);
                    final marked = widget.markedDays.contains(day);
                    final enabled = _enabled(day);
                    final isToday = day == today;
                    return Semantics(
                      button: true,
                      selected: selected,
                      enabled: enabled,
                      label: '${DateFormat('EEEE d MMMM').format(day)}${marked ? ', has events' : ''}',
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: AppRadius.mdAll,
                        onTap: enabled ? () => widget.onSelected(day) : null,
                        child: Container(
                          height: 44,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: selected ? scheme.primary : null,
                            borderRadius: AppRadius.mdAll,
                            border: isToday && !selected ? Border.all(color: scheme.primary) : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${index + 1}',
                                style: context.text.bodyMedium?.copyWith(
                                  color: selected
                                      ? scheme.onPrimary
                                      : enabled
                                          ? scheme.onSurface
                                          : scheme.onSurface.withValues(alpha: 0.35),
                                  fontWeight: marked ? FontWeight.w800 : FontWeight.w400,
                                ),
                              ),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: marked
                                      ? (selected ? scheme.onPrimary : scheme.secondary)
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }
}
