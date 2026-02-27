# Ell-ena Frontend Setup Guide

This document provides a comprehensive guide to set up the Flutter frontend for the Ell-ena project. Follow these steps to get your frontend up and running and connected to the Supabase backend.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installing Flutter SDK](#installing-flutter-sdk)
3. [Setting Up an IDE](#setting-up-an-ide)
4. [Setting Up Emulators/Simulators](#setting-up-emulatorssimulators)
5. [Cloning and Setting Up the Ell-ena Project](#cloning-and-setting-up-the-ell-ena-project)
6. [Connecting to the Supabase Backend](#connecting-to-the-supabase-backend)
7. [Running the Application](#running-the-application)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

Before you begin, ensure you have the following:

- **Operating System**: Windows 10 or later (64-bit) / macOS 10.14 or later
- **Disk Space**: At least 2.5 GB of free space
- **RAM**: Minimum 4 GB (8 GB recommended)
- **Tools**:
  - **Windows**: PowerShell 5.0 or later, Git for Windows
  - **macOS**: bash, curl, git 2.x, mkdir, rm, unzip, which

## Installing Flutter SDK

### For Windows

1. **Download Flutter SDK**:
   - Visit the [Flutter Windows Installation](https://docs.flutter.dev/get-started/install/windows) page.
   - Download the latest stable release of the Flutter SDK.

2. **Extract the SDK**:
   - Create a folder where you want to install Flutter (e.g., `C:\src\flutter`).
   - Extract the downloaded zip file into this folder.
   - Avoid paths that require elevated privileges (e.g., `C:\Program Files\`).

3. **Update System PATH**:
   - Add Flutter to your PATH environment variable:
     - Press `Win + S` and type "environment variables"
     - Click on "Edit the system environment variables"
     - Click on "Environment Variables" button
     - Under "System variables", find and select the "Path" variable, then click "Edit"
     - Click "New" and add the path to `flutter\bin` (e.g., `C:\src\flutter\bin`)
     - Click "OK" on all dialogs to save the changes

4. **Verify Installation**:
   - Open a new Command Prompt window and run:
   ```
   flutter --version
   ```
   - Then run the Flutter doctor command to check for any dependencies you need to install:
   ```
   flutter doctor
   ```
   - Follow any instructions provided by the Flutter doctor to complete the setup.

### For macOS

1. **Download Flutter SDK**:
   - Visit the [Flutter macOS Installation](https://docs.flutter.dev/get-started/install/macos) page.
   - Download the latest stable release of the Flutter SDK.

2. **Extract the SDK**:
   - Open Terminal and navigate to the desired location (e.g., your home directory):
   ```bash
   cd ~/development
   ```
   - Extract the downloaded file:
   ```bash
   unzip ~/Downloads/flutter_macos_*.zip
   ```

3. **Update System PATH**:
   - Add Flutter to your PATH:
   ```bash
   export PATH="$PATH:$HOME/development/flutter/bin"
   ```
   - To make this change permanent, add the above line to your shell profile file:
   ```bash
   echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
   ```
   - If you're using Bash, use `~/.bash_profile` instead of `~/.zshrc`.
   - Restart your terminal or run `source ~/.zshrc` (or `source ~/.bash_profile`) to apply the changes.

4. **Install Xcode (for iOS development)**:
   - Install Xcode from the Mac App Store.
   - Open Xcode and accept the license agreement.
   - Install the Xcode command-line tools:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

5. **Install CocoaPods**:
   - CocoaPods is required for iOS development:
   ```bash
   sudo gem install cocoapods
   ```

6. **Verify Installation**:
   - Open Terminal and run:
   ```bash
   flutter --version
   flutter doctor
   ```
   - Follow any instructions provided by the Flutter doctor to complete the setup.

## Setting Up an IDE

You can use either Visual Studio Code (VS Code) or Android Studio for Flutter development.

### Visual Studio Code

1. **Install VS Code**:
   - Download and install [Visual Studio Code](https://code.visualstudio.com/).

2. **Install Flutter and Dart Extensions**:
   - Open VS Code.
   - Go to Extensions (Ctrl+Shift+X or Cmd+Shift+X).
   - Search for "Flutter" and install the official Flutter extension.
   - This will automatically install the Dart extension as well.

3. **Verify Setup**:
   - Open the Command Palette (Ctrl+Shift+P or Cmd+Shift+P).
   - Type "Flutter: New Project" to verify that the Flutter extension is working.

### Android Studio

1. **Install Android Studio**:
   - Download and install [Android Studio](https://developer.android.com/studio).

2. **Install Flutter and Dart Plugins**:
   - Open Android Studio.
   - Go to Preferences/Settings > Plugins.
   - Search for "Flutter" and install the plugin.
   - This will automatically install the Dart plugin as well.
   - Restart Android Studio when prompted.

3. **Verify Setup**:
   - Open Android Studio.
   - Click on "Start a new Flutter project" to verify that the Flutter plugin is working.

## Setting Up Emulators/Simulators

### Android Emulator

1. **Install Android SDK**:
   - If you installed Android Studio, you already have the Android SDK.
   - Otherwise, you can install it separately using the Android SDK Command-line Tools.

2. **Create an Android Virtual Device (AVD)**:
   - Open Android Studio.
   - Click on "Configure" > "AVD Manager".
   - Click on "Create Virtual Device".
   - Select a device definition (e.g., Pixel 4) and click "Next".
   - Select a system image (preferably the latest stable Android version) and click "Next".
   - Give your AVD a name and click "Finish".

3. **Start the Emulator**:
   - In Android Studio, click on the AVD Manager and start your emulator.
   - Alternatively, you can start it from the command line:
   ```
   flutter emulators --launch <emulator_id>
   ```
   - To list available emulators:
   ```
   flutter emulators
   ```

### iOS Simulator (macOS Only)

1. **Install Xcode**:
   - Ensure Xcode is installed as described in the Flutter installation steps.

2. **Open the Simulator**:
   - Run the following command in Terminal:
   ```bash
   open -a Simulator
   ```
   - Alternatively, you can use Flutter to launch the simulator:
   ```bash
   flutter emulators --launch apple_ios_simulator
   ```

3. **Select Device Type**:
   - In the Simulator, go to File > Open Simulator and select the desired device.

## Cloning and Setting Up the Ell-ena Project

1. **Clone the Repository**:
   - Open your terminal or command prompt.
   - Navigate to the directory where you want to store the project.
   - Clone the repository:
   ```
   git clone <repository-url>
   cd Ell-ena
   ```

2. **Install Dependencies**:
   - Run the following command to get all the required packages:
   ```
   flutter pub get
   ```

3. **Set Up Environment Variables**:
   - Copy the `.env.example` file to create a new `.env` file:
   ```
   cp .env.example .env
   ```
   - Update the `.env` file with your Supabase credentials (as described in the BACKEND.md guide):
   ```
   SUPABASE_URL=<YOUR_SUPABASE_URL>
   SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>
   GEMINI_API_KEY=<YOUR_GEMINI_API_KEY>
   VEXA_API_KEY=<YOUR_VEXA_API_KEY>
   ```

## Connecting to the Supabase Backend

The Ell-ena project is already configured to connect to Supabase. The connection is established in the `lib/services/supabase_service.dart` file.

1. **Ensure Backend is Set Up**:
   - Make sure you have completed all the steps in the BACKEND.md guide.
   - Your Supabase project should be up and running with all the required tables and functions.

2. **Configure Environment Variables**:
   - Ensure your `.env` file contains the correct Supabase URL and anon key.
   - These values can be found in your Supabase dashboard under Settings > API.

3. **Initialize Supabase**:
   - The project already initializes Supabase in the `main.dart` file through the `SupabaseService().initialize()` method.
   - This method loads the environment variables and sets up the Supabase client.

## Running the Application

1. **Check Available Devices**:
   - Run the following command to see all available devices:
   ```
   flutter devices
   ```

2. **Run the App**:
   - To run on all connected devices:
   ```
   flutter run
   ```
   - To run on a specific device:
   ```
   flutter run -d <device-id>
   ```
   - To run in release mode (for better performance):
   ```
   flutter run --release
   ```

3. **Debug Mode Features**:
   - While the app is running in debug mode, you can:
     - Press `r` to hot-reload the app (apply code changes without restarting).
     - Press `R` to hot-restart the app (completely restart the app).
     - Press `q` to quit the app.
     - Press `v` to print the Flutter framework version.

## Building for Production

### Android

1. **Create a Keystore**:
   - If you don't have a keystore, create one:
   ```
   keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
   ```

2. **Configure Signing**:
   - Create a file at `android/key.properties` with the following content:
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=key
   storeFile=<path-to-keystore>
   ```
   - Update the `android/app/build.gradle` file to use these signing configurations.

3. **Build the APK**:
   ```
   flutter build apk --release
   ```
   - The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`.

4. **Build App Bundle**:
   ```
   flutter build appbundle --release
   ```
   - The bundle will be available at `build/app/outputs/bundle/release/app-release.aab`.

### iOS (macOS Only)

1. **Update iOS Bundle Identifier**:
   - Open `ios/Runner.xcworkspace` in Xcode.
   - Select the Runner project in the navigator, then select the Runner target.
   - In the General tab, update the Bundle Identifier to a unique identifier.

2. **Set Up Signing**:
   - In the Signing & Capabilities tab, select your team and set up signing.

3. **Build the App**:
   ```
   flutter build ios --release
   ```

4. **Archive and Upload**:
   - Open the project in Xcode:
   ```
   open ios/Runner.xcworkspace
   ```
   - Select Product > Archive to create an archive.
   - Use the Xcode Organizer to validate and upload your app to the App Store.

## Troubleshooting

### Common Issues and Solutions

1. **Flutter Doctor Warnings**:
   - Run `flutter doctor -v` for detailed information about issues.
   - Follow the recommendations to resolve each issue.

2. **Dependency Issues**:
   - If you encounter package conflicts, try:
   ```
   flutter clean
   flutter pub get
   ```

3. **Build Errors**:
   - For Android build issues, check your Android SDK installation and ensure you have the required build tools.
   - For iOS build issues, ensure Xcode is properly installed and you have the necessary signing certificates.

4. **Supabase Connection Issues**:
   - Verify your Supabase URL and anon key in the `.env` file.
   - Check if your Supabase project is up and running.
   - Ensure your database tables and functions are properly set up as described in BACKEND.md.

5. **Permission Issues**:
   - The app requires certain permissions (e.g., microphone access for speech-to-text). Ensure these permissions are granted in the device settings.

### Getting Help


### Improve Troubleshooting Section

6. **Windows Desktop Build Fails**:
   - Ensure Visual Studio 2022 is installed.
   - Make sure "Desktop development with C++" workload is selected.
   - Run:
     ```
     flutter doctor -v
     ```
   - Resolve any Windows toolchain issues reported.

If you encounter issues not covered in this guide:

- Check the [Flutter Documentation](https://docs.flutter.dev/)
- Visit the [Supabase Documentation](https://supabase.com/docs)
- Join the Ell-ena Discord channel for community support
- Open an issue on the project's GitHub repository

---

This guide should help you set up the Ell-ena frontend and connect it to the Supabase backend. For more detailed information about specific features or customizations, please refer to the project documentation or contact the development team.
