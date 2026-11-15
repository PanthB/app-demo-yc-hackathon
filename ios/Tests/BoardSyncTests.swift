import SwiftData
import XCTest
@testable import AppDemo

@MainActor
final class BoardSyncTests: XCTestCase {
    private var context: ModelContext!

    override func setUpWithError() throws {
        context = ModelContext(BoardStore.makeInMemoryContainer())
    }

    private func rows(_ json: String) throws -> LossyList<RemoteDrop> {
        try JSONDecoder().decode(LossyList<RemoteDrop>.self, from: Data(json.utf8))
    }

    private func row(_ changes: [String: Any] = [:]) throws -> RemoteDrop {
        var fields: [String: Any] = [
            "_id": "j970d2wkmnvmjasqg1w8r4s79x8j8kfm", "_creationTime": 1794769305052.3457,
            "boardId": "sf-crew", "clientId": "5EED0000-0000-4000-8000-000000000007",
            "authorId": "seed-maya", "authorName": "maya", "authorColor": "blue",
            "kind": "url", "url": "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC",
            "imageIds": [String](), "imageUrls": [String](), "capturedAt": 1794769297844.0, "utcOffsetMinutes": -480.0,
            "status": "processed", "title": "Never Gonna Give You Up", "zone": "vibes", "zoneSetByUser": false,
            "pinned": false, "relatedClientIds": ["nk2-web"], "suggestion": "sam saved this too.",
            "enrichment": ["provider": "spotify oembed + og tags", "author": "Rick Astley"],
            "extraction": ["confidence": 0.3, "kindWords": ["song"], "vibeWords": [String](), "whenLabel": "saturday at 7pm", "startsAt": 1795316400000.0, "price": 25.0, "area": 7] as [String: Any],
            "decision": ["type": "song", "zone": "vibes", "objectKind": "record", "emphasis": "pulseOnce", "unsure": false] as [String: Any],
            "pipeline": ["enrich": ["ran": "done"]], "updatedAt": 1794769303159.0,
        ]
        fields.merge(changes) { _, new in new }
        let data = try JSONSerialization.data(withJSONObject: [fields])
        return try XCTUnwrap(JSONDecoder().decode(LossyList<RemoteDrop>.self, from: data).elements.first)
    }

    private func landed(_ remote: RemoteDrop) -> Drop {
        let drop = remote.makeDrop(id: DropKey.id(for: remote.clientId))
        context.insert(drop)
        remote.apply(to: drop, holdingPlacement: false)
        return drop
    }

    func testARowThatCantBeReadIsLeftOutAndTheRestStillArrive() throws {
        let list = try rows(#"[{"_id": "broken"}, 7, {"_id": "a", "boardId": "b", "clientId": "c", "authorId": "p", "kind": "text", "capturedAt": 1, "status": "pending"}]"#)

        XCTAssertEqual(list.elements.map(\.clientId), ["c"])
        XCTAssertEqual(list.skipped, 2)
    }

    func testAFriendsDropLandsWithWhoSavedItAndWhatWasRead() throws {
        let drop = landed(try row())

        XCTAssertEqual(drop.id, UUID(uuidString: "5EED0000-0000-4000-8000-000000000007"))
        XCTAssertEqual(drop.boardId, "sf-crew")
        XCTAssertEqual(drop.authorId, "seed-maya")
        XCTAssertEqual(drop.authorName, "maya")
        XCTAssertEqual(drop.authorColor, "blue")
        XCTAssertEqual(drop.suggestion, "sam saved this too.")
        XCTAssertEqual(drop.status, .processed)
        XCTAssertEqual(drop.title, "Never Gonna Give You Up")
        XCTAssertEqual(drop.artist, "Rick Astley")
        XCTAssertEqual(drop.type, .song)
        XCTAssertEqual(drop.objectKind, .record)
        XCTAssertEqual(drop.emphasis, .pulseOnce)
        XCTAssertEqual(drop.zone, .vibes)
        XCTAssertFalse(drop.zoneSetByUser)
        XCTAssertFalse(drop.isPinned)
        XCTAssertEqual(drop.whenLabel, "saturday at 7pm")
        XCTAssertEqual(drop.price, "$25")
        XCTAssertEqual(drop.startsAt, Date(timeIntervalSince1970: 1_795_316_400))
        XCTAssertEqual(drop.createdAt, Date(timeIntervalSince1970: 1_794_769_297.844))
        XCTAssertEqual(drop.relatedDropIds, [DropKey.id(for: "nk2-web")])
    }

    func testThePipelineNeverMovesADropThePersonPlaced() throws {
        let drop = landed(try row())
        drop.moveByUser(to: .tonight)

        try row().apply(to: drop, holdingPlacement: false)

        XCTAssertEqual(drop.zone, .tonight)
        XCTAssertTrue(drop.zoneSetByUser)
    }

    func testAFriendsMoveAndPinReachThisPhone() throws {
        let drop = landed(try row())
        let moved = try row(["zone": "done", "zoneSetByUser": true, "previousZone": "vibes", "pinned": true, "pinnedAt": 1794769400000.0])

        moved.apply(to: drop, holdingPlacement: false)

        XCTAssertEqual(drop.zone, .done)
        XCTAssertTrue(drop.zoneSetByUser)
        XCTAssertEqual(drop.previousZone, .vibes)
        XCTAssertEqual(drop.pinnedAt, Date(timeIntervalSince1970: 1_794_769_400))
    }

    func testAnOlderListDoesNotUndoAChangeStillOnItsWayOut() throws {
        let drop = landed(try row())
        drop.setPinned(true)
        drop.moveByUser(to: .now)

        try row().apply(to: drop, holdingPlacement: true)

        XCTAssertTrue(drop.isPinned)
        XCTAssertEqual(drop.zone, .now)
    }

    func testADropLandsInItsClusterWithItsVibesNeighborsGenreAndLength() throws {
        let drop = landed(try row([
            "vibes": ["dreamy", "late night", "pop"], "clusterId": "c1", "clusterLabel": "late night, dreamy",
            "neighbors": [
                ["clientId": "5eed0000-0000-4000-8000-000000000009", "reason": "both dreamy, late night."],
                ["clientId": "nk2-web", "reason": "both pop."],
            ],
            "enrichment": ["provider": "spotify oembed + og tags + deezer", "author": "Rick Astley", "genre": "pop", "bpm": 113.2, "durationSec": 213] as [String: Any],
        ]))

        XCTAssertEqual(drop.vibes, ["dreamy", "late night", "pop"])
        XCTAssertEqual(drop.clusterId, "c1")
        XCTAssertEqual(drop.clusterLabel, "late night, dreamy")
        XCTAssertEqual(drop.neighbors, [
            DropNeighbor(clientId: "5EED0000-0000-4000-8000-000000000009", reason: "both dreamy, late night."),
            DropNeighbor(clientId: DropKey.id(for: "nk2-web").uuidString, reason: "both pop."),
        ])
        XCTAssertEqual(drop.genre, "pop")
        XCTAssertEqual(drop.mediaDuration, 213)
    }

    func testADropLeavesItsClusterWhenTheBackendTakesItOut() throws {
        let drop = landed(try row([
            "vibes": ["dreamy"], "clusterId": "c1", "clusterLabel": "dreamy",
            "neighbors": [["clientId": "nk2-web", "reason": "both dreamy."]],
            "enrichment": ["author": "Rick Astley", "genre": "pop", "durationSec": 213.4] as [String: Any],
        ]))

        try row(["zone": "done", "zoneSetByUser": true, "vibes": ["dreamy"], "neighbors": [[String: String]]()]).apply(to: drop, holdingPlacement: false)

        XCTAssertNil(drop.clusterId)
        XCTAssertNil(drop.clusterLabel)
        XCTAssertTrue(drop.neighbors.isEmpty)
        XCTAssertEqual(drop.vibes, ["dreamy"])
        XCTAssertEqual(drop.genre, "pop")
        XCTAssertEqual(drop.mediaDuration, 213.4)
    }

    func testAPhotoWithNoCutoutOnThisPhoneIsAPolaroid() throws {
        let photo = try row(["kind": "image", "decision": ["type": "place", "objectKind": "cutout", "emphasis": "normal", "unsure": false] as [String: Any]])

        XCTAssertEqual(landed(photo).objectKind, .polaroid)
    }

    func testClientIdsThatAreNotUUIDsStillGetOneStableId() {
        XCTAssertEqual(DropKey.id(for: "nk2-song"), DropKey.id(for: "nk2-song"))
        XCTAssertNotEqual(DropKey.id(for: "nk2-song"), DropKey.id(for: "nk2-web"))
        XCTAssertEqual(DropKey.id(for: "5eed0000-0000-4000-8000-000000000007"), UUID(uuidString: "5EED0000-0000-4000-8000-000000000007"))
    }

    func testEveryNumberSentToTheBackendIsADouble() throws {
        let saved = Date(timeIntervalSince1970: 1_794_772_000)
        let drop = Drop(createdAt: saved, authorId: "seed-panth", boardId: "sf-crew", sourceKind: .text, rawText: "remind me in 1 hr to call mom")
        DropReader.readWords(of: drop)
        var reading = DropReading()
        reading.storageIds = ["a", "b", "c", "d", "e"]
        let zone = try XCTUnwrap(TimeZone(secondsFromGMT: -8 * 3600))

        let args = DropSubmit.arguments(for: drop, reading: reading, boardId: "sf-crew", personId: "seed-panth", timeZone: zone)

        XCTAssertEqual(args["clientId"] as? String, drop.id.uuidString)
        XCTAssertEqual(args["capturedAt"] as? Double, 1_794_772_000_000)
        XCTAssertEqual(args["utcOffsetMinutes"] as? Double, -480)
        XCTAssertEqual((args["imageIds"] as? [Any?])?.count, 4)
        let hints = try XCTUnwrap(args["hints"] as? [String: Any?])
        XCTAssertEqual(hints["dueAt"] as? Double, 1_794_775_600_000)
        XCTAssertNil(args["latitude"] as? Double)
        XCTAssertEqual(drop.zone, .now)
        XCTAssertEqual(drop.whenLabel, "in 1 hr")
    }

    func testASharedLinkPassesItsCaptionAsTheLinkTitle() throws {
        let drop = Drop(authorId: "me", sourceKind: .url, rawText: "best ramen in the mission\nsecond line", url: "https://www.tiktok.com/@a/video/1")

        let args = DropSubmit.arguments(for: drop, reading: DropReading(), boardId: "b", personId: "me")

        XCTAssertEqual((args["hints"] as? [String: Any?])?["linkTitle"] as? String, "best ramen in the mission")
    }

    func testASharedSongSendsItsNameAndArtistWithoutTheSiteName() throws {
        let drop = Drop(authorId: "me", sourceKind: .url, rawText: "Blinding Lights - song and lyrics by The Weeknd | Spotify", url: "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b")
        DropReader.readLink(of: drop)

        let args = DropSubmit.arguments(for: drop, reading: DropReading(), boardId: "b", personId: "me")

        XCTAssertEqual(drop.title, "Blinding Lights")
        XCTAssertEqual(drop.artist, "The Weeknd")
        let hints = try XCTUnwrap(args["hints"] as? [String: Any?])
        XCTAssertEqual(hints["linkTitle"] as? String, "Blinding Lights")
        XCTAssertEqual(hints["artist"] as? String, "The Weeknd")
    }

    func testASharedPlaceSendsItsNameAndWhereItIs() throws {
        let drop = Drop(authorId: "me", sourceKind: .url, rawText: "Tadaima", url: "https://maps.apple.com/place?address=3515%2020th%20St,%20Ste%20B,%20San%20Francisco&coordinate=37.758509,-122.419611&name=Tadaima&place-id=IE280BA887A0204F9&map=explore")
        DropReader.readLink(of: drop)

        let args = DropSubmit.arguments(for: drop, reading: DropReading(), boardId: "b", personId: "me")

        XCTAssertEqual(drop.placeName, "Tadaima")
        XCTAssertEqual((args["hints"] as? [String: Any?])?["placeName"] as? String, "Tadaima")
        XCTAssertEqual(args["latitude"] as? Double, 37.758509)
        XCTAssertEqual(args["longitude"] as? Double, -122.419611)
    }

    func testASharedGoogleMapsPlaceIsTitledByItsNameNotTheSite() throws {
        let drop = Drop(authorId: "me", sourceKind: .url, rawText: "Google Maps", url: "https://www.google.com/maps/place/Tartine+Bakery/@37.7614347,-122.4240821,16z/data=!3m1!4b1!4m6!3m5!1s0x808f7e1807365605:0x601f7a97f0ce6c6b!8m2!3d37.7614347!4d-122.4240821")
        DropReader.readLink(of: drop)

        let args = DropSubmit.arguments(for: drop, reading: DropReading(), boardId: "b", personId: "me")

        XCTAssertEqual(drop.title, "Tartine Bakery")
        let hints = try XCTUnwrap(args["hints"] as? [String: Any?])
        XCTAssertEqual(hints["linkTitle"] as? String, "Tartine Bakery")
        XCTAssertEqual(hints["placeName"] as? String, "Tartine Bakery")
        XCTAssertEqual(args["latitude"] as? Double, 37.7614347)
        XCTAssertEqual(args["longitude"] as? Double, -122.4240821)
    }

    func testTheSampleBoardsDropsAreNeverSent() {
        XCTAssertTrue(DropKey.isSample(SeedBoard.clientId(board: 1, 15)))
        XCTAssertTrue(DropKey.isSample(DropKey.id(for: "5eed0000-0000-4000-8000-000000000007")))
        XCTAssertFalse(DropKey.isSample(DropKey.id(for: "nk2-song")))
        XCTAssertFalse(DropKey.isSample(UUID()))
    }

    func testAnInviteLinkGivesItsCode() throws {
        XCTAssertEqual(BoardsStore.inviteCode(in: try XCTUnwrap(URL(string: "appdemo://join/SFCREW"))), "SFCREW")
        XCTAssertNil(BoardsStore.inviteCode(in: try XCTUnwrap(URL(string: "appdemo://join"))))
        XCTAssertNil(BoardsStore.inviteCode(in: try XCTUnwrap(URL(string: "appdemo://view/cards"))))
    }

    func testPastedWordsBecomeALinkOnlyWhenTheyAreOne() {
        XCTAssertEqual(AddMenu.link(from: "maps.apple.com/?q=tartine"), "https://maps.apple.com/?q=tartine")
        XCTAssertEqual(AddMenu.link(from: "https://example.com/a"), "https://example.com/a")
        XCTAssertNil(AddMenu.link(from: "ramen saturday 7pm"))
        XCTAssertNil(AddMenu.link(from: "ramen"))
    }
}
