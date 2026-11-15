# ShareExtension

Owner: the share and ingest thread (PAN-5). Keep a class named `ShareViewController`, because `Config/ShareExtension-Info.plist` names it as the principal class.

This target compiles `ios/ShareExtension` and `ios/Shared` by folder, with `APPLICATION_EXTENSION_API_ONLY` on, so code in `ios/Shared` can't use `UIApplication.shared`. The activation rule accepts urls, images, movies, audio, plain text and pdfs.

## What it does

`ShareViewController` hands the shared items to `ShareCollector`, which writes them to the app group inbox with `Inbox.shared`, then shows `ShareNote`, a native glass card over the app the person shared from, for 2 seconds or until it is tapped, and closes. The card says "dropped it, i'll find it a spot.", or "dropped it in sf crew." when the current board is a shared one. The extension records that board for each item it saved, so the drop lands where the card said. It makes no network calls and reads nothing but file metadata. The app does the slow work after it ingests the inbox.

Files are copied on disk with `loadFileRepresentation`, never loaded into memory. An image that arrives only as an object, with no file behind it, is the one exception, because it is already in memory.

## How a share becomes drops

- A share with a web link is one `url` drop. The page title and any text that came with it go in `text`, and any media files in the same share ride along as that drop's files.
- A share of media files with no link is one drop per file: `image`, `video`, `audio` or `pdf`. Text that came with it goes on the first one. A photo's GPS position from its metadata goes in `latitude` and `longitude`.
- Text alone is a `text` drop. If the text is nothing but a link it is a `url` drop, and if it only contains a link the link is also kept in `url`.

## Checking it on a phone

The confirmation text has the accessibility identifier `shareConfirmation`. Errors are logged with `Logger.share`.
