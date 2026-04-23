import Foundation

actor KnowledgeGraph {
    private let loader: KnowledgeGraphLoader
    private var cached: KnowledgeIndex?

    init(loader: KnowledgeGraphLoader = KnowledgeGraphLoader()) {
        self.loader = loader
    }

    func index() -> KnowledgeIndex {
        if let cached { return cached }
        let fresh = loader.load()
        cached = fresh
        return fresh
    }

    func file(id: String) -> KnowledgeFile? {
        index().file(id: id)
    }

    func files(type: KnowledgeType) -> [KnowledgeFile] {
        index().files(type: type)
    }
}
