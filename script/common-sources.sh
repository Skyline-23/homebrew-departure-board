#!/bin/bash
# One source list for the app, screen saver and native tests.
COMMON_SOURCES=()

for name in Diagnostics DepartureSchedule Localization DestinationStore AirlineLogoStore BackgroundAgent \
            LiveFlightStore SettingsStore UserInstallation BoardView DrawingSupport BoardChrome \
            AirportRenderer SplitFlapRenderer SettingsController; do
  COMMON_SOURCES+=("$PROJECT_ROOT/Sources/$name.m")
done
COMMON_SOURCES+=("$PROJECT_ROOT"/Sources/Airports/*.m "$PROJECT_ROOT"/Sources/Airports/Adapters/*.m)
APP_SOURCES=("$PROJECT_ROOT/Sources/WallpaperRenderer.m" "$PROJECT_ROOT/Sources/DesktopController.m" \
             "$PROJECT_ROOT/Sources/CommandLine.m")
