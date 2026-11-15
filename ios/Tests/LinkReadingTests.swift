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
