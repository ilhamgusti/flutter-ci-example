# Flutter CI Example

Example Flutter project for testing GitHub Actions CI/CD pipeline.

## What's included

- Simple Flutter app (Material 3)
- Widget test
- GitHub Actions workflow for Android APK build

## CI/CD Pipeline

On every push/PR to `master`:
1. Set up Java 17 + Flutter (cached)
2. Run `flutter doctor`
3. Install dependencies
4. Run `flutter analyze`
5. Run tests
6. Build debug APK
7. Upload APK as artifact (downloadable from Actions tab)

## Local run

```bash
flutter pub get
flutter test
flutter build apk --debug
```

## Based on

[Automating Flutter Android Builds with GitHub Actions](https://medium.com/@abhayshankur/automating-flutter-android-builds-with-github-actions-77c172653525)
