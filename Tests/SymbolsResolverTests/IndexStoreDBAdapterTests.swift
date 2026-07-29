import Foundation
import IndexStoreDB
import Testing
@testable import SymbolsResolver

@Suite("IndexStoreDB adapter")
struct IndexStoreDBAdapterTests {
    @Test("File modules come from occurrence locations")
    func readsModuleFromLocation() {
        let occurrences = [
            occurrence(kind: .variable, roles: .definition, module: "Ignored"),
            occurrence(kind: .struct, roles: .definition, module: "FeatureModule"),
        ]

        #expect(IndexStoreDBAdapter.moduleName(from: occurrences) == "FeatureModule")
    }

    @Test("Definitions and declarations of allowed kinds are candidates")
    func acceptsAllowedKindsAndRoles() {
        let definition = occurrence(kind: .class, roles: .definition)
        let declaration = occurrence(kind: .protocol, roles: .declaration)

        #expect(IndexStoreDBAdapter.isResolutionCandidate(definition))
        #expect(IndexStoreDBAdapter.isResolutionCandidate(declaration))
    }

    @Test("References and forbidden declaration kinds are rejected")
    func rejectsForbiddenCandidates() {
        let reference = occurrence(kind: .struct, roles: .reference)
        let functionDeclaration = occurrence(kind: .function, roles: .declaration)

        #expect(!IndexStoreDBAdapter.isResolutionCandidate(reference))
        #expect(!IndexStoreDBAdapter.isResolutionCandidate(functionDeclaration))
    }

    private func occurrence(
        kind: IndexSymbolKind,
        roles: SymbolRole,
        module: String = "App"
    ) -> SymbolOccurrence {
        SymbolOccurrence(
            symbol: Symbol(
                usr: "not-a-mangled-usr",
                name: "Example",
                kind: kind,
                language: .swift
            ),
            location: SymbolLocation(
                path: "/Projects/App/Example.swift",
                timestamp: Date(timeIntervalSince1970: 0),
                moduleName: module,
                line: 1,
                utf8Column: 1
            ),
            roles: roles,
            symbolProvider: .swift
        )
    }
}
