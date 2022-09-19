import SwiftSyntax

public struct IBInspectableInExtensionRule: SwiftSyntaxRule, ConfigurationProviderRule, OptInRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "ibinspectable_in_extension",
        name: "IBInspectable in Extension",
        description: "Extensions shouldn't add @IBInspectable properties.",
        kind: .lint,
        nonTriggeringExamples: [
            Example("""
            class Foo {
              @IBInspectable private var x: Int
            }
            """)
        ],
        triggeringExamples: [
            Example("""
            extension Foo {
              ↓@IBInspectable private var x: Int
            }
            """)
        ]
    )

    public func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor? {
        Visitor()
    }
}

private extension IBInspectableInExtensionRule {
    final class Visitor: SyntaxVisitor, ViolationsSyntaxVisitor {
        private(set) var violationPositions: [AbsolutePosition] = []

        override func visitPost(_ node: AttributeSyntax) {
            if node.attributeName.text == "IBInspectable" && node.inExtension {
                violationPositions.append(node.positionAfterSkippingLeadingTrivia)
            }
        }
    }
}

private extension SyntaxProtocol {
    var inExtension: Bool {
        var nextParent = parent
        while let parent = nextParent {
            if parent.is(ExtensionDeclSyntax.self) {
                return true
            } else {
                nextParent = parent.parent
            }
        }
        return false
    }
}
