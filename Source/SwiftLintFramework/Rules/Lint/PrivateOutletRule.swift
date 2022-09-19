import SwiftSyntax

public struct PrivateOutletRule: SwiftSyntaxRule, OptInRule, ConfigurationProviderRule {
    public var configuration = PrivateOutletRuleConfiguration(allowPrivateSet: false)

    public init() {}

    public static let description = RuleDescription(
        identifier: "private_outlet",
        name: "Private Outlets",
        description: "IBOutlets should be private to avoid leaking UIKit to higher layers.",
        kind: .lint,
        nonTriggeringExamples: [
            Example("class Foo {\n  @IBOutlet private var label: UILabel?\n}\n"),
            Example("class Foo {\n  @IBOutlet private var label: UILabel!\n}\n"),
            Example("class Foo {\n  var notAnOutlet: UILabel\n}\n"),
            Example("class Foo {\n  @IBOutlet weak private var label: UILabel?\n}\n"),
            Example("class Foo {\n  @IBOutlet private weak var label: UILabel?\n}\n")
        ],
        triggeringExamples: [
            Example("class Foo {\n  @IBOutlet ↓var label: UILabel?\n}\n"),
            Example("class Foo {\n  @IBOutlet ↓var label: UILabel!\n}\n")
        ]
    )

    public func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor? {
        Visitor(allowPrivateSet: configuration.allowPrivateSet)
    }

    public func makeViolation(file: SwiftLintFile, position: AbsolutePosition) -> StyleViolation {
        StyleViolation(
            ruleDescription: Self.description,
            severity: configuration.severityConfiguration.severity,
            location: Location(file: file, position: position)
        )
    }
}

private extension PrivateOutletRule {
    final class Visitor: SyntaxVisitor, ViolationsSyntaxVisitor {
        private(set) var violationPositions: [AbsolutePosition] = []
        private let allowPrivateSet: Bool

        init(allowPrivateSet: Bool) {
            self.allowPrivateSet = allowPrivateSet
        }

        override func visitPost(_ node: MemberDeclListItemSyntax) {
            guard
                let decl = node.decl.as(VariableDeclSyntax.self),
                decl.attributes?.hasIBOutlet == true,
                decl.modifiers?.isPrivateOrFilePrivate != true
            else {
                return
            }

            if allowPrivateSet && decl.modifiers?.isPrivateSet == true {
                return
            }

            violationPositions.append(decl.letOrVarKeyword.positionAfterSkippingLeadingTrivia)
        }
    }
}

private extension AttributeListSyntax {
    var hasIBOutlet: Bool {
        contains { $0.as(AttributeSyntax.self)?.attributeName.text == "IBOutlet" }
    }
}

private extension ModifierListSyntax {
    var isPrivateOrFilePrivate: Bool {
        contains { ["private", "fileprivate"].contains($0.name.text) }
    }

    var isPrivateSet: Bool {
        contains { $0.withoutTrivia().description == "private(set)" }
    }
}
