//
//  Tags.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 19.04.2025.
//

import Testing

extension Tag {

    enum symbolKind {
        @Tag static var `import`: Tag

        @Tag static var definition: Tag
        @Tag static var usage: Tag
    }

    enum semantics {
        @Tag static var declaration: Tag
        @Tag static var expression: Tag
    }

    enum syntaxFeature {
        @Tag static var generic: Tag
        @Tag static var constraint: Tag
        @Tag static var compoundConstraint: Tag

        @Tag static var whereClause: Tag

        @Tag static var opaque: Tag
        @Tag static var existential: Tag

        @Tag static var memberName: Tag
    }
}
