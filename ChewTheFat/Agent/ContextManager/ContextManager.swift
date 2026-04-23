import Foundation

@MainActor
final class ContextManager {
    private let sources: [ContextSourceProtocol]
    private let assembler: ContextAssembler

    init(sources: [ContextSourceProtocol], assembler: ContextAssembler = ContextAssembler()) {
        self.sources = sources
        self.assembler = assembler
    }

    func prompt(for request: ContextRequest) async -> AssembledContext {
        var fragments: [ContextFragment] = []
        for source in sources {
            let contribution = await source.contribute(for: request)
            fragments.append(contentsOf: contribution)
        }
        return assembler.assemble(fragments: fragments)
    }
}
