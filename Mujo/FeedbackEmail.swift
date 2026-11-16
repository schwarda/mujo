import Foundation

enum FeedbackEmail {
    static let recipient: String? = "info@aikaristudio.com"
    static let supportPage = "https://aikaristudio.com/support/"

    static func draftURL(recipient: String, appVersion: String?, iOSVersion: String) -> URL? {
        let newline = "\r\n"
        let appDetails = appVersion.map { ["Mujo \($0)"] } ?? []
        let details = appDetails + ["iOS \(iOSVersion)"]

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Mujo Feedback"),
            URLQueryItem(name: "body", value: newline + newline + details.joined(separator: newline)),
        ]
        return components.url
    }
}
