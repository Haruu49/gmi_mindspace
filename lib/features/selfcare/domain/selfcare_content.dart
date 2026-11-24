import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Self-care categories from the brief.
enum SelfCareCategory {
  relaxation('Relaxation', Icons.spa_outlined, AppColors.lavender),
  stress('Stress Management', Icons.self_improvement_rounded, AppColors.sageDeep),
  breathing('Breathing Exercises', Icons.air_rounded, Color(0xFF6FA3C7)),
  mindfulness('Mindfulness', Icons.center_focus_strong_outlined, AppColors.success),
  sleep('Sleep Hygiene', Icons.bedtime_outlined, Color(0xFF7D7AB8)),
  emotions('Emotional Regulation', Icons.favorite_border_rounded, AppColors.error),
  balance('Study-Life Balance', Icons.balance_rounded, AppColors.warning);

  const SelfCareCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// How an activity is carried out.
enum ActivityKind { guided, breathing, grounding, gratitude }

class SelfCareActivity {
  const SelfCareActivity({
    required this.id,
    required this.title,
    required this.category,
    required this.minutes,
    required this.summary,
    required this.steps,
    this.kind = ActivityKind.guided,
    this.tip,
  });

  final String id;
  final String title;
  final SelfCareCategory category;
  final int minutes;
  final String summary;
  final List<String> steps;
  final ActivityKind kind;
  final String? tip;
}

/// Short, evidence-informed everyday activities. Wording is friendly and
/// non-clinical; none of these claim to treat any condition.
abstract final class SelfCareLibrary {
  static const activities = <SelfCareActivity>[
    SelfCareActivity(
      id: 'calm-breathing',
      title: 'Calm breathing',
      category: SelfCareCategory.breathing,
      minutes: 3,
      kind: ActivityKind.breathing,
      summary: 'Slow, steady breaths with a visual guide. Adjust the pace to suit you.',
      steps: [
        'Sit comfortably and let your shoulders drop.',
        'Breathe in through your nose as the circle grows.',
        'Hold gently while it pauses.',
        'Breathe out slowly as it shrinks. Stop whenever you like.',
      ],
      tip: 'A longer out-breath than in-breath often feels calming.',
    ),
    SelfCareActivity(
      id: 'grounding-54321',
      title: '5-4-3-2-1 grounding',
      category: SelfCareCategory.mindfulness,
      minutes: 4,
      kind: ActivityKind.grounding,
      summary: 'Use your five senses to bring your attention back to the present.',
      steps: [
        'Notice 5 things you can see.',
        'Notice 4 things you can touch.',
        'Notice 3 things you can hear.',
        'Notice 2 things you can smell.',
        'Notice 1 thing you can taste.',
      ],
    ),
    SelfCareActivity(
      id: 'three-good-things',
      title: 'Three good things',
      category: SelfCareCategory.emotions,
      minutes: 5,
      kind: ActivityKind.gratitude,
      summary: 'Write down three positive things from today, big or small.',
      steps: [
        'Think back over your day.',
        'Write three things that went well or that you appreciated.',
        'For each, note why it mattered to you.',
      ],
      tip: 'Your list is saved privately in your journal.',
    ),
    SelfCareActivity(
      id: 'muscle-relaxation',
      title: 'Quick muscle relaxation',
      category: SelfCareCategory.relaxation,
      minutes: 6,
      summary: 'Gently tense and release muscle groups to let go of physical tension.',
      steps: [
        'Sit or lie down somewhere comfortable.',
        'Curl your toes for 5 seconds, then release for 10 seconds.',
        'Tighten your legs, then release.',
        'Clench your hands into fists, then release.',
        'Raise your shoulders to your ears, then let them drop.',
        'Scrunch your face, then relax it. Notice how your body feels.',
      ],
      tip: 'Tense gently – it should never hurt.',
    ),
    SelfCareActivity(
      id: 'body-scan',
      title: 'Mini body scan',
      category: SelfCareCategory.relaxation,
      minutes: 5,
      summary: 'Move your attention slowly through your body without judging.',
      steps: [
        'Close your eyes or soften your gaze.',
        'Notice your feet, then your legs, without trying to change anything.',
        'Move your attention up through your back, chest and arms.',
        'Notice your neck, jaw and face. Let them soften.',
        'Take one slow breath and open your eyes.',
      ],
    ),
    SelfCareActivity(
      id: 'break-it-down',
      title: 'Break it down',
      category: SelfCareCategory.stress,
      minutes: 5,
      summary: 'Turn one overwhelming task into small, doable steps.',
      steps: [
        'Write down the task that feels biggest right now.',
        'List the very first small step (5–10 minutes).',
        'Add two or three more small steps.',
        'Do only the first step, then take a short break.',
      ],
    ),
    SelfCareActivity(
      id: 'worry-time',
      title: 'Scheduled worry time',
      category: SelfCareCategory.stress,
      minutes: 10,
      summary: 'Give worries a set time so they take up less of your day.',
      steps: [
        'Pick a 10-minute slot later today.',
        'When a worry pops up, jot it down and save it for that slot.',
        'In worry time, read your list. Circle what you can act on.',
        'Choose one small action. Let the rest go until tomorrow.',
      ],
    ),
    SelfCareActivity(
      id: 'move-for-five',
      title: 'Move for five',
      category: SelfCareCategory.stress,
      minutes: 5,
      summary: 'A short walk or stretch to reset your body and mind.',
      steps: [
        'Stand up and stretch your arms overhead.',
        'Roll your shoulders and neck gently.',
        'Walk for a few minutes – outside if you can.',
        'Notice your surroundings as you move.',
      ],
    ),
    SelfCareActivity(
      id: 'mindful-minute',
      title: 'Mindful minute',
      category: SelfCareCategory.mindfulness,
      minutes: 1,
      summary: 'One minute of simply noticing your breath.',
      steps: [
        'Set a one-minute timer.',
        'Notice the air moving in and out.',
        'When your mind wanders, gently come back to the breath.',
      ],
    ),
    SelfCareActivity(
      id: 'wind-down',
      title: 'Evening wind-down',
      category: SelfCareCategory.sleep,
      minutes: 30,
      summary: 'A calm routine to help your mind and body get ready for sleep.',
      steps: [
        'Aim to go to bed and wake up at similar times each day.',
        'Put screens away 30–60 minutes before bed if you can.',
        'Keep your room cool, dark and quiet.',
        'Avoid caffeine in the late afternoon and evening.',
        'Do something relaxing: reading, stretching or calm music.',
        'If you cannot sleep after a while, get up and do something quiet until you feel sleepy.',
      ],
    ),
    SelfCareActivity(
      id: 'sleep-habits',
      title: 'Healthy sleep habits',
      category: SelfCareCategory.sleep,
      minutes: 3,
      summary: 'Simple daytime habits that support better nights.',
      steps: [
        'Get some daylight in the morning.',
        'Keep naps short (under 30 minutes) and early in the day.',
        'Try not to study in bed – keep bed for sleep.',
        'Write tomorrow\'s to-do list before bed to clear your mind.',
      ],
    ),
    SelfCareActivity(
      id: 'name-it',
      title: 'Name it to tame it',
      category: SelfCareCategory.emotions,
      minutes: 3,
      summary: 'Putting feelings into words can make them easier to manage.',
      steps: [
        'Pause and ask: what am I feeling right now?',
        'Try to name it precisely – e.g. "frustrated" rather than "bad".',
        'Notice where you feel it in your body.',
        'Remind yourself: feelings come and go.',
      ],
    ),
    SelfCareActivity(
      id: 'stop-skill',
      title: 'The STOP pause',
      category: SelfCareCategory.emotions,
      minutes: 2,
      summary: 'A quick pause before reacting when emotions run high.',
      steps: [
        'S – Stop what you are doing.',
        'T – Take a slow breath.',
        'O – Observe your thoughts, feelings and surroundings.',
        'P – Proceed with something helpful.',
      ],
    ),
    SelfCareActivity(
      id: 'focus-blocks',
      title: 'Focus blocks',
      category: SelfCareCategory.balance,
      minutes: 30,
      summary: 'Study in focused blocks with real breaks in between.',
      steps: [
        'Choose one task and silence notifications.',
        'Work for 25 minutes.',
        'Take a 5-minute break away from your screen.',
        'After four blocks, take a longer break.',
      ],
    ),
    SelfCareActivity(
      id: 'balanced-week',
      title: 'Plan a balanced week',
      category: SelfCareCategory.balance,
      minutes: 10,
      summary: 'Make room for rest, people and fun – not only study.',
      steps: [
        'Write down fixed commitments: classes, work, deadlines.',
        'Add study blocks for the week.',
        'Schedule at least one thing you enjoy each day.',
        'Protect time for sleep, meals and movement.',
      ],
    ),
  ];

  static SelfCareActivity? byId(String id) {
    for (final a in activities) {
      if (a.id == id) return a;
    }
    return null;
  }

  static List<SelfCareActivity> inCategory(SelfCareCategory c) =>
      activities.where((a) => a.category == c).toList();
}
