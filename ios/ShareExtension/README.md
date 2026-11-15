# ShareExtension

Owner: the share and ingest thread (PAN-5). Keep a class named `ShareViewController`, because `Config/ShareExtension-Info.plist` names it as the principal class.

This target compiles `ios/ShareExtension` and `ios/Shared` by folder, with `APPLICATION_EXTENSION_API_ONLY` on, so code in `ios/Shared` can't use `UIApplication.shared`. The activation rule accepts urls, images, movies, audio, plain text and pdfs.

## What it does

`ShareViewController` hands the shared items to `ShareCollector`, which writes them to the app group inbox with `Inbox.shared`, and shows `ShareNote`, a native glass card. The card is there from the first frame, saying "hang on, i'm grabbing it." until the save ends. It then stays for 2 seconds counted from when the sheet is on screen, or until it is tapped, fades out and closes. The card says "dropped it, i'll find it a spot.", or "dropped it in sf crew." when the current board is a shared one. The extension records that board for each item it saved, so the drop lands where the card said. It reads nothing but file metadata. The app does the slow work after it ingests the inbox.

For a link share the extension also sends the drop straight to Convex (`ShareSend`): one `drops:submit` call over HTTP with the arguments the app would send, so friends see it without the sharer opening the app. The call gets 2 seconds and the sheet never waits for it: the note's own 2 seconds are longer, and a note tapped away early just leaves the drop to the app. The inbox copy stays as the retry path, and the app's own send later changes nothing, because `drops:submit` returns the row that already has that `clientId`. Text, photos and files, short `maps.app.goo.gl` links and place links without coordinates are left for the app, which reads them first. The deployment URL comes from the app group (`convexURL`), which the app writes on every wake, so nothing is sent before the app has run once, or while it runs offline with the sample board.

Files are copied on disk with `loadFileRepresentation`, never loaded into memory. An image that arrives only as an object, with no file behind it, is the one exception, because it is already in memory.

The card sits in the full-height sheet iOS 26 presents for every share extension. The extension can't change that sheet: a clear background, `modalPresentationStyle = .overFullScreen`, `preferredContentSize` and subclassing `SLComposeServiceViewController` all still got the sheet on the iOS 26.5 Simulator. iOS empties the sheet the moment `completeRequest` is called and then slides it away, so the card fades out first instead of vanishing halfway down.

## How a share becomes drops

- A share with a web link is one `url` drop. The page title and any text that came with it go in `text`, and any media files in the same share ride along as that drop's files.
- A share of media files with no link is one drop per file: `image`, `video`, `audio` or `pdf`. Text that came with it goes on the first one. A photo's GPS position from its metadata goes in `latitude` and `longitude`.
- Text alone is a `text` drop. If the text is nothing but a link it is a `url` drop, and if it only contains a link the link is also kept in `url`.

## Checking it on a phone

In a DEBUG build, opening `appdemo://debug/hold-share-note` keeps the card up until it is tapped, so a test that looks at the screen late still sees it. `appdemo://debug/release-share-note` turns that off again. The switch is the app group flag `holdShareNote`, and it lasts until it is released or the app is deleted.

The confirmation text has the accessibility identifier `shareConfirmation`. Errors are logged with `Logger.share`, which also logs "the share card is on screen" when the sheet has finished opening.
