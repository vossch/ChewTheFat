import Foundation

/// Loads markdown knowledge files bundled in `ChewTheFat/Resources/Knowledge/`.
/// Each file uses a small front-matter block:
/// ```
/// ---
/// id: skill-onboarding
/// type: skill
/// title: Onboarding
/// summary: One-line description
/// tags: onboarding, intake
/// ---
/// (markdown body)
/// ```
nonisolated struct KnowledgeGraphLoader: Sendable {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func load() -> KnowledgeIndex {
        let urls = bundle.urls(forResourcesWithExtension: "md", subdirectory: "Knowledge") ?? []
        let entries = urls.compactMap(parse(url:))
        return KnowledgeIndex(entries: entries)
    }

    func parse(url: URL) -> KnowledgeFile? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parse(text: text)
    }

    func parse(text: String) -> KnowledgeFile? {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        var idx = 1
        var meta: [String: String] = [:]
        while idx < lines.count {
            let line = lines[idx]
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                idx += 1
                break
            }
            if let colon = line.firstIndex(of: ":") {
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                meta[key] = value
            }
            idx += 1
        }
        guard let id = meta["id"],
              let typeRaw = meta["type"],
              let type = KnowledgeType(rawValue: typeRaw),
              let title = meta["title"] else {
            return nil
        }
        let summary = meta["summary"] ?? ""
        let tags = (meta["tags"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let body = lines[idx...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return KnowledgeFile(id: id, type: type, title: title, summary: summary, tags: tags, body: body)
    }
}
