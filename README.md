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

## Backend API

The `backend/` directory contains a FastAPI service backed by PostgreSQL that
persists calendar events. You can run it locally with Docker:

```bash
cd backend
docker compose up --build
```

This exposes the API at `http://localhost:8000` (Swagger docs at `/docs`).
See `backend/README.md` for details, alternative setup instructions, and the
schema description.

## Connecting the Flutter app

The Flutter showcase reads events from the API at launch. By default it points
to `http://localhost:8000`, which works for the iOS simulator. If you are using
a physical device, pass an overriden base URL so it can reach your machine:

```bash
flutter run --dart-define=NURSESHIFT_API_URL=http://192.168.1.50:8000
```

Replace the host with your computer's LAN IP address.

### iOS devices

The repo now includes the generated `ios/` Runner project. To launch it on a simulator or a physical device:

1. Run `flutter run -d ios` for quick simulator testing, or open `ios/Runner.xcworkspace` in Xcode.
2. Set your signing team in *Runner > Signing & Capabilities* if you plan to deploy to hardware.
3. Select the target device and press Run from either Flutter CLI or Xcode.

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
