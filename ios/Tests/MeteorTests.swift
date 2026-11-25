import XCTest
@testable import Meteor

final class MeteorTests: XCTestCase {
    func testPanelCredentialsAreSeparatedFromProviderAndIdentity() throws {
        let o: Object = ["status":"active", "expires_at": Date().timeIntervalSince1970 + 1000, "connection":["server":"https://provider.example", "username":"test-user", "password":"test-password"], "additional_sources":[["id":"m3u", "name":"Other", "type":"m3u", "url":"https://example.test/list.m3u", "enabled":true], ["id":"disabled", "type":"m3u", "url":"https://example.test/no", "enabled":false]]]
        let panel = try PanelState(o); XCTAssertTrue(panel.active); XCTAssertEqual(panel.sources.count,2); XCTAssertEqual(panel.sources[0].id,"main")
        XCTAssertFalse(try PanelState(["status":"blocked"]).active)
        XCTAssertFalse(try PanelState(["status":"active", "expires_at":1]).active)
        XCTAssertThrowsError(try PanelState([:]))
    }
    func testStreamAndAPIEncodingPreservesCredentialsAndRejectsInjection() throws {
        let source = Source(id:"main", name:"Test", type:"xtream", server:"https://provider.example/iptv/", username:"u+ser/one", password:"p&/?# +")
        let api = try source.api("get_live_streams", ["category_id":"a&b"])
        let c = try XCTUnwrap(URLComponents(url:api,resolvingAgainstBaseURL:false))
        XCTAssertEqual(c.queryItems?.first(where:{$0.name=="password"})?.value,source.password)
        XCTAssertTrue(api.absoluteString.contains("%2B")); XCTAssertFalse(api.absoluteString.contains("secret="))
        let stream = try source.stream("live","123","m3u8"); XCTAssertTrue(stream.absoluteString.contains("u%2Bser%2Fone")); XCTAssertTrue(stream.absoluteString.hasSuffix("123.m3u8"))
        XCTAssertThrowsError(try source.stream("live","../123","m3u8")); XCTAssertThrowsError(try source.stream("live","1","ts?x=1"))
        XCTAssertNil(httpURL("file:///private/data")); XCTAssertNil(httpURL("https://user:pass@provider.example")); XCTAssertNil(httpURL("javascript:alert(1)"))
    }
    func testM3UQuotedCommaAttributesBOMAndRadioClassification() throws {
        let data = "\u{FEFF}#EXTM3U\r\n#EXTINF:-1 tvg-name=\"fallback\" group-title=\"SK, HU\" tvg-logo=\"https://example.test/a.png\",ČT 1, HD\r\n#EXTVLCOPT:http-user-agent=custom\r\nhttps://example.test/live.m3u8?x=1&token=abc%2F123\r\n#EXTINF:-1 group-title=\"Radio\",FM\nhttps://example.test/a.mp3\n"
        let items = try M3UParser.parse(data,sourceID:"one")
        XCTAssertEqual(items.count,2); XCTAssertEqual(items[0].name,"ČT 1, HD"); XCTAssertEqual(items[0].category,"SK, HU"); XCTAssertTrue(items[0].address.hasSuffix("token=abc%2F123")); XCTAssertEqual(items[1].kind,.radio)
    }
    func testM3UStableIdentityAndDuplicatesDoNotLeakURLs() throws {
        let line = "#EXTINF:-1,Test\nhttps://example.test/live?password=test-only\n"
        let first = try M3UParser.parse("#EXTM3U\n"+line+line,sourceID:"s")
        let second = try M3UParser.parse("#EXTM3U\n#EXTINF:-1,Other\nhttps://example.test/other\n"+line,sourceID:"s")
        XCTAssertEqual(first.count,2); XCTAssertNotEqual(first[0].id,first[1].id); XCTAssertEqual(first[0].id,second[1].id); XCTAssertFalse(first[0].id.contains("password"))
        XCTAssertThrowsError(try M3UParser.parse("<html>error</html>",sourceID:"s"))
    }
    func testCatchupDateUsesProviderTimezoneAndDurationRoundsUp() throws {
        let source = Source(id:"s",name:"Test",type:"xtream",server:"https://example.test",username:"u",password:"p")
        let start = Date(timeIntervalSince1970:1735689600)
        let url = try source.archive("17",start:start,end:start.addingTimeInterval(61),zone:TimeZone(identifier:"Europe/Bratislava")!)
        XCTAssertTrue(url.absoluteString.contains("/2/2025-01-01:01-00/17.m3u8"))
        XCTAssertThrowsError(try source.archive("17",start:start,end:start,zone:.current))
        let p = Programme(id:"1",title:"Test",description:"",start:start,end:start.addingTimeInterval(60))
        XCTAssertTrue(p.playable(days:1,now:start.addingTimeInterval(100))); XCTAssertFalse(p.playable(days:0,now:start.addingTimeInterval(100))); XCTAssertFalse(p.playable(days:1,now:start.addingTimeInterval(90000)))
    }
    func testSafeMetadataDecoding() { XCTAssertEqual(decodedTitle("VGVzdA=="),"Test"); XCTAssertEqual(decodedTitle("Radio FM"),"Radio FM"); XCTAssertEqual(decodedTitle("AA=="),"AA==") }
    func testCodableSourceRoundTripRetainsLocalImportAndPasswords() throws {
        var source = Source(id:"abc",name:"File",type:"m3u"); source.localFile="abc.m3u"
        XCTAssertEqual(try JSONDecoder().decode(Source.self,from:JSONEncoder().encode(source)),source)
    }
}
