import Foundation

struct KnowledgeContextSource: ContextSourceProtocol {
    let graph: KnowledgeGraph
    let selector: KnowledgeSelector

    init(graph: KnowledgeGraph, selector: KnowledgeSelector = KnowledgeSelector()) {
        self.graph = graph
        self.selector = selector
    }

    var name: String { "knowledge" }

    func contribute(for request: ContextRequest) async -> [ContextFragment] {
        let index = await graph.index()
        let selection = selector.selectFor(goal: request.goal, in: index)
        return selection.files.map { file in
            ContextFragment(
                label: "Knowledge: \(file.title)",
                body: file.body,
                priority: .normal
            )
        }
    }
}
