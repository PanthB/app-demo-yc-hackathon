# Assets

Asset catalogs for the app target. `Kit.xcassets` (the SVG kit) belongs to APPD-8. Any `.xcassets` folder added here is bundled as a resource by folder (see `ios/project.yml`), so it needs no project edit.

The app icon needs one project setting (`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`), which APPD-3 turns on once an `AppIcon` set lands in the kit.
