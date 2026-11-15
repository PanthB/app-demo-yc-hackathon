# ShareExtension

Owner: the share and ingest thread (PAN-5). `ShareViewController.swift` is a stub from the skeleton that keeps links and text only. Replace it freely, but keep a class named `ShareViewController`, because `Config/ShareExtension-Info.plist` names it as the principal class.

This target compiles `ios/ShareExtension` and `ios/Shared` by folder, with `APPLICATION_EXTENSION_API_ONLY` on, so code in `ios/Shared` can't use `UIApplication.shared`. The activation rule accepts urls, images, movies, audio, plain text and pdfs.
