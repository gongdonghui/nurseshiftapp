# NurseShift UI Kit

This lightweight Flutter UI kit re-creates the visual language from the provided NurseShift screenshots: rounded segmented tabs, teal primary buttons, search inputs, informational cards, and the bottom navigation bar.

## Structure

- `lib/theme` – central color and typography tokens plus the `ThemeData` builder
- `lib/widgets` – the reusable widgets (`NurseButton`, `NurseTextField`, `ShiftCard`, `InfoCard`, `ColleagueSuggestionCard`, `SegmentedTabs`, `NurseBottomNav`)
- `lib/main.dart` – a small showcase page that stitches the widgets together

## Running the showcase

```bash
flutter pub get
flutter run
```

The home screen mimics the calendar and colleagues tabs from the screenshots so you can visually confirm the result.

## Reuse guide

```dart
final button = NurseButton(
  label: 'Add Colleagues',
  leading: const Icon(Icons.person_add_alt_rounded),
  onPressed: () {},
);

final input = const NurseTextField(
  label: 'Search colleagues',
  hint: 'Search colleagues',
  leadingIcon: Icons.search,
);

final card = ColleagueSuggestionCard(
  name: 'Isabel Zhang',
  department: 'Weight Management',
  facility: 'F.W. Huston Medical Center',
  onConnect: () {},
);
```

Each widget exposes clear parameters, so you can plug them into your own screens without copying layout code. Update the color or typography tokens inside `lib/theme` to propagate any future branding changes automatically.
