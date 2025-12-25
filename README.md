# NurseShift UI Kit

This lightweight Flutter UI kit re-creates the visual language from the provided mynurseshift screenshots: rounded segmented tabs, teal primary buttons, search inputs, informational cards, and the bottom navigation bar.

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

## Group invite links (deep link flow)

The group page now generates invitation links like `https://yourdomain.com/ginv/<token>`. Share the link from the app and test with:

1. Tap **Invite** in a group card.
2. Share the generated link.
3. Open the link on a device. If the app is installed, it deep-links to the invite preview page. If not, it opens a landing page with the download button.

### Invite API (minimal backend)

```
POST /groups/{groupId}/invites
GET  /invites/{token}/preview
POST /invites/{token}/redeem
POST /invites/{token}/revoke   (optional)
GET  /ginv/{token}             (universal link landing page)
```

The backend stores only a hash of the token along with expiration and usage limits.

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

## Universal Links / App Links setup

### iOS

1. Enable Associated Domains in `ios/Runner.xcodeproj` (Signing & Capabilities).
2. Add `applinks:yourdomain.com` to `Runner.entitlements`.
3. Host the AASA file at:
   - `https://yourdomain.com/.well-known/apple-app-site-association`

Example AASA (replace team id + bundle id):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "ABCDE12345.com.your.bundle",
        "paths": [ "/ginv/*" ]
      }
    ]
  }
}
```

### Android

1. Add intent-filters for `https://yourdomain.com/ginv/*` to `AndroidManifest.xml`.
2. Host `assetlinks.json` at:
   - `https://yourdomain.com/.well-known/assetlinks.json`

Example assetlinks.json:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.your.bundle",
      "sha256_cert_fingerprints": ["AA:BB:CC:..."]
    }
  }
]
```

### Local testing

Use `app_links` initial link testing or run:

```
https://yourdomain.com/ginv/<token>
```

When using a device on local network, update `INVITE_LINK_BASE_URL` in the backend to match the domain or IP you test against.

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
