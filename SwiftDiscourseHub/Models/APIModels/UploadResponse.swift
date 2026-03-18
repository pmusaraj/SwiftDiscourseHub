struct UploadResponse: Codable {
    let id: Int
    let url: String
    let shortUrl: String
    let originalFilename: String
    let filesize: Int
    let width: Int?
    let height: Int?
    let humanFilesize: String?
}
