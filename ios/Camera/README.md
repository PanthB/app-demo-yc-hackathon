# Camera

Owner: APPD-21. The in-app camera that takes a photo and drops it onto the current board. `NSCameraUsageDescription` is set in `ios/project.yml`.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.

## What hosts use

`DropCamera()` is a full-screen view with no arguments. Present it with `fullScreenCover`. It reads `BoardSync`, `BoardsStore` and the model context from the environment (`.dropPipeline()` puts them there), so it works anywhere under the root view.

Each photo is written to the same inbox the share extension and `AddMenu`'s photo item use (`CameraInbox.drop`), then `sync.wake(in:)` puts it on the current board. The photo is written the moment it's taken, before the animation, so closing the camera mid-flight never loses a photo.

## What it does

- A custom AVFoundation camera (`CameraModel`, `CameraPreview`): the live preview fills the screen, with Liquid Glass controls for close, flash, zoom and flip, tap to focus, pinch to zoom, and the shutter. The volume buttons and Camera Control take a photo through `onCameraCaptureEvent`, and Camera Control's zoom slider is added when the session supports controls.
- A chip names the board the photo lands in: "dropping into sf crew.", then "dropped it into sf crew." for a moment after each photo.
- The moment (`CaptureFlight`): the shutter squishes on touch down, a quick white flash and a haptic fire when the photo is taken, the frozen frame shrinks into a rounded, tilted card with a soft shadow, lifts, then drops along an arc into the chip, where it lands in a small fanned stack with a settle and a second haptic. Every part is a spring or a short ease-out, nothing blocks the shutter, and several photos can be in the air at once. Under Reduce Motion the frame cross-fades into the chip instead and the flash is dimmer.
- Permission states (`CameraAccessView`): before asking, after a denial (a button to Settings and a photo picker instead), and no camera (a photo picker). Returning from Settings checks again.

## Debug

- On the Simulator, in DEBUG, the viewfinder shows sample stills from `ios/Seed/SeedImages.xcassets` and each photo advances to the next one. `-CameraDebugStill YES` does the same on a device.
- `-CameraDebugAutoShoot <seconds>` takes three photos, the first after that many seconds and then one every 2.2 seconds, so the moment can be recorded with `simctl io recordVideo`.
- `-CameraDebugOpen YES` opens the camera at launch, through `.cameraDebugLauncher()` on the root view (a no-op outside DEBUG).

Errors are logged with `Logger.camera`.
