# Camera

Owner: APPD-21. The in-app camera that takes a photo and drops it onto the current board. `NSCameraUsageDescription` is set in `ios/project.yml`.

Compiled into the app target by folder (see `ios/project.yml`), so a new file here needs no project edit. Markdown files are excluded from the build.

## What hosts use

`DropCamera()` is a full-screen view with no arguments. Present it with `fullScreenCover`. It reads `BoardSync`, `BoardsStore` and the model context from the environment (`.dropPipeline()` puts them there), so it works anywhere under the root view.

Each photo is written to the same inbox the share extension and `AddMenu`'s photo item use (`CameraInbox.drop`), then `sync.wake(in:)` puts it on the current board. The photo is written the moment it's taken, before the animation, so closing the camera mid-flight never loses a photo.

## What it does

- A custom AVFoundation camera (`CameraModel`, `CameraPreview`): the live preview fills the screen. Close and flash sit at the top; a zoom capsule (1×, 2), the last-photo thumbnail, the shutter and flip sit at the bottom, all Liquid Glass in one `GlassEffectContainer`. Tap to focus, pinch to zoom. The volume buttons and Camera Control take a photo through `onCameraCaptureEvent`, and Camera Control's zoom slider is added when the session supports controls.
- The moment (`CaptureFlight`): the shutter squishes on touch down; a short flash on the viewfinder only (under the controls) and a haptic fire when the photo is taken; the frozen frame shrinks into a 4:5 white-bordered card with a slight tilt and a soft shadow, then falls into the last-photo thumbnail at the bottom left, landing exactly on its frame. The thumbnail takes over on contact, pops, shows a count, and fires a success haptic. Nothing blocks the shutter, and several photos can be in the air at once. Under Reduce Motion the frame cross-fades into the thumbnail instead and the flash is dimmer.
- Status: at rest the board's name sits quietly beside the thumbnail. While a photo is flying a capsule says "dropping it in sf crew.", then "dropped it in sf crew." for 2.5 seconds before it fades. Tapping the thumbnail closes the camera onto the board.
- Permission states (`CameraAccessView`): before asking, after a denial (a button to Settings and a photo picker instead), and no camera (a photo picker). Returning from Settings checks again.

## Debug

- On the Simulator, in DEBUG, the viewfinder shows sample stills from `ios/Seed/SeedImages.xcassets` and each photo advances to the next one. `-CameraDebugStill YES` does the same on a device.
- Sample photos only go into the inbox when `-BoardDebugSeed YES` keeps the board offline, so a Simulator run never sends them to the dev deployment.
- `-CameraDebugAutoShoot <seconds>` takes three photos, the first after that many seconds and then one every 2.2 seconds, so the moment can be recorded with `simctl io recordVideo`.
- `-CameraDebugOpen YES` opens the camera at launch, through `.cameraDebugLauncher()` on the root view (a no-op outside DEBUG).
- `-CameraDebugAccess notAsked|denied|unavailable` shows a permission state.

Errors are logged with `Logger.camera`.
