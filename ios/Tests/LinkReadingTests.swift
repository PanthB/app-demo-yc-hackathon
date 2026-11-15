import XCTest
@testable import AppDemo

final class LinkReadingTests: XCTestCase {
    func testASpotifyPageTitleGivesTheSongAndTheArtist() {
        let seen = LinkReading.read("https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b?si=abc", caption: "Blinding Lights - song and lyrics by The Weeknd | Spotify")

        XCTAssertEqual(seen, LinkReading.Seen(title: "Blinding Lights", artist: "The Weeknd"))
    }

    func testAnAppleMusicPageTitleGivesTheSongAndTheArtist() {
        let seen = LinkReading.read("https://music.apple.com/us/song/pink-white/1146195713", caption: "\u{200E}Pink + White – Song by Frank Ocean – Apple Music")

        XCTAssertEqual(seen, LinkReading.Seen(title: "Pink + White", artist: "Frank Ocean"))
    }

    func testASongLinkWithNoPageTitleIsLeftForTheBackendToRead() {
        XCTAssertEqual(LinkReading.read("https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b", caption: nil), LinkReading.Seen())
        XCTAssertEqual(LinkReading.read("https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b", caption: "this one, on repeat"), LinkReading.Seen())
    }

    func testAnAppleMapsLinkGivesThePlaceAndWhereItIs() {
        let seen = LinkReading.read("https://maps.apple.com/place?address=3515%2020th%20St,%20Ste%20B,%20San%20Francisco,%20CA%20%2094110,%20United%20States&coordinate=37.758509,-122.419611&name=Tadaima&place-id=IE280BA887A0204F9&map=explore", caption: "Tadaima")

        XCTAssertEqual(seen, LinkReading.Seen(placeName: "Tadaima", latitude: 37.758509, longitude: -122.419611))
    }

    func testAnOlderAppleMapsLinkGivesThePlaceAndWhereItIs() {
        let seen = LinkReading.read("https://maps.apple.com/?q=Tartine%20Bakery&ll=37.7614,-122.4241", caption: nil)

        XCTAssertEqual(seen, LinkReading.Seen(placeName: "Tartine Bakery", latitude: 37.7614, longitude: -122.4241))
    }

    func testAGoogleMapsLinkGivesThePlaceAndWhereItIs() {
        let seen = LinkReading.read("https://www.google.com/maps/place/Tartine+Bakery/@37.7614206,-122.4241312,17z/data=!3m1!4b1", caption: "Tartine Bakery - Google Maps")

        XCTAssertEqual(seen, LinkReading.Seen(placeName: "Tartine Bakery", latitude: 37.7614206, longitude: -122.4241312))
    }

    func testAGoogleMapsLinkPrefersThePinOverTheMapsCenter() {
        let seen = LinkReading.read("https://www.google.co.kr/maps/place/Tartine+Bakery/@37.7620000,-122.4250000,16z/data=!3m1!4b1!4m6!3m5!1s0x808f7e1807365605:0x601f7a97f0ce6c6b!8m2!3d37.7614347!4d-122.4240821!16s%2Fm%2F03gmfm5?entry=tts", caption: nil)

        XCTAssertEqual(seen, LinkReading.Seen(placeName: "Tartine Bakery", latitude: 37.7614347, longitude: -122.4240821))
    }

    func testAGoogleMapsLinkWithOnlyANameAndAddressSaysWhatToLookUp() {
        let fromThePath = LinkReading.read("https://www.google.com/maps/place/Tartine+Bakery,+600+Guerrero+St,+San+Francisco,+CA+94110", caption: "Google Maps")
        let fromTheQuery = LinkReading.read("https://maps.google.com/?q=Tartine+Bakery,+600+Guerrero+St,+San+Francisco,+CA+94110&ftid=0x808f7e1807365605:0x601f7a97f0ce6c6b", caption: nil)
        let expected = LinkReading.Seen(placeName: "Tartine Bakery", placeSearch: "Tartine Bakery, 600 Guerrero St, San Francisco, CA 94110")

        XCTAssertEqual(fromThePath, expected)
        XCTAssertEqual(fromTheQuery, expected)
    }

    func testAGoogleMapsSearchLinkGivesTheNameOrTheSpot() {
        XCTAssertEqual(
            LinkReading.read("https://www.google.com/maps/search/?api=1&query=Tartine+Bakery", caption: nil),
            LinkReading.Seen(placeName: "Tartine Bakery", placeSearch: "Tartine Bakery")
        )
        XCTAssertEqual(
            LinkReading.read("https://www.google.com/maps/search/?api=1&query=37.7614347,-122.4240821", caption: nil),
            LinkReading.Seen(latitude: 37.7614347, longitude: -122.4240821)
        )
        XCTAssertEqual(
            LinkReading.read("https://maps.google.com/?q=Tartine+Bakery&ll=37.7614,-122.4241", caption: nil),
            LinkReading.Seen(placeName: "Tartine Bakery", latitude: 37.7614, longitude: -122.4241)
        )
    }

    func testAGoogleMapsRouteIsNotAPlace() {
        let seen = LinkReading.read("https://www.google.com/maps/dir/Sausalito,+California+94965/257+San+Jose+Ave,+San+Francisco,+CA+94110/@37.8044739,-122.4931306,13061m/data=!3m2!1e3!4b1", caption: nil)

        XCTAssertEqual(seen, LinkReading.Seen())
    }

    func testAnAppleMapsLinkWithNoCoordinateSaysWhatToLookUp() {
        let seen = LinkReading.read("https://maps.apple.com/place?address=600%20Guerrero%20St,%20San%20Francisco&name=Tartine%20Bakery", caption: nil)

        XCTAssertEqual(seen, LinkReading.Seen(placeName: "Tartine Bakery", placeSearch: "Tartine Bakery, 600 Guerrero St, San Francisco"))
    }

    func testOnlyShortMapsLinksAreFollowed() {
        XCTAssertTrue(LinkReading.isShortMapsLink("https://maps.app.goo.gl/bsHd5CAixFpr1oPn8?g_st=ic"))
        XCTAssertTrue(LinkReading.isShortMapsLink("https://goo.gl/maps/AbCdEf123"))
        XCTAssertFalse(LinkReading.isShortMapsLink("https://goo.gl/forms/AbCdEf123"))
        XCTAssertFalse(LinkReading.isShortMapsLink("https://www.google.com/maps/place/Tartine+Bakery"))
        XCTAssertFalse(LinkReading.isShortMapsLink("https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b"))
    }

    func testAShortMapsLinkAndOtherLinksSayNothing() {
        XCTAssertEqual(LinkReading.read("https://maps.app.goo.gl/AbCdEf123", caption: "Tartine Bakery"), LinkReading.Seen())
        XCTAssertEqual(LinkReading.read("https://www.google.com/search?q=tartine", caption: nil), LinkReading.Seen())
        XCTAssertEqual(LinkReading.read("https://www.tiktok.com/@a/video/1", caption: "best ramen in the mission"), LinkReading.Seen())
    }

    func testTheCaptionsFirstLineDropsTheSiteName() {
        XCTAssertEqual(LinkReading.firstLine(of: "Guess My Scrambled Name Challenge on TikTok! | TikTok"), "Guess My Scrambled Name Challenge on TikTok!")
        XCTAssertEqual(LinkReading.firstLine(of: "marufuku ramen - YouTube\nsecond line"), "marufuku ramen")
        XCTAssertEqual(LinkReading.firstLine(of: "best ramen in the mission"), "best ramen in the mission")
        XCTAssertNil(LinkReading.firstLine(of: "  \n"))
        XCTAssertNil(LinkReading.firstLine(of: nil))
    }
}
