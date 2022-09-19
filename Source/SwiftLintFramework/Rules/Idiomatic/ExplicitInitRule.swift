import SwiftSyntax

public struct ExplicitInitRule: SwiftSyntaxCorrectableRule, ConfigurationProviderRule, OptInRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "explicit_init",
        name: "Explicit Init",
        description: "Explicitly calling .init() should be avoided.",
        kind: .idiomatic,
        nonTriggeringExamples: [
            Example("""
            import Foundation
            class C: NSObject {
                override init() {
                    super.init()
                }
            }
            """), // super
            Example("""
            struct S {
                let n: Int
            }
            extension S {
                init() {
                    self.init(n: 1)
                }
            }
            """), // self
            Example("""
            [1].flatMap(String.init)
            """), // pass init as closure
            Example("""
            [String.self].map { $0.init(1) }
            """), // initialize from a metatype value
            Example("""
            [String.self].map { type in type.init(1) }
            """), // initialize from a metatype value
            Example("""
            Observable.zip(obs1, obs2, resultSelector: MyType.init).asMaybe()
            """),
            Example("""
            Observable.zip(
              obs1,
              obs2,
              resultSelector: MyType.init
            ).asMaybe()
            """)
        ],
        triggeringExamples: [
            Example("""
            [1].flatMap{String↓.init($0)}
            """),
            Example("""
            [String.self].map { Type in Type↓.init(1) }
            """),  // Starting with capital letter assumes a type
            Example("""
            func foo() -> [String] {
                return [1].flatMap { String↓.init($0) }
            }
            """),
            Example("""
            Observable.zip(
              obs1,
              obs2,
              resultSelector: { MyType↓.init($0, $1) }
            ).asMaybe()
            """),
            Example("""
            let int = In🤓t↓
            .init(1.0)
            """, excludeFromDocumentation: true),
            Example("""
            let int = Int↓


            .init(1.0)
            """, excludeFromDocumentation: true),
            Example("""
            let int = Int↓


                  .init(1.0)
            """, excludeFromDocumentation: true)
        ],
        corrections: [
            Example("""
            [1].flatMap{String↓.init($0)}
            """):
                Example("""
                [1].flatMap{String($0)}
                """),
            Example("""
            func foo() -> [String] {
                return [1].flatMap { String↓.init($0) }
            }
            """):
                Example("""
                func foo() -> [String] {
                    return [1].flatMap { String($0) }
                }
                """),
            Example("""
            class C {
            #if true
                func f() {
                    [1].flatMap{String↓.init($0)}
                }
            #endif
            }
            """):
                Example("""
                class C {
                #if true
                    func f() {
                        [1].flatMap{String($0)}
                    }
                #endif
                }
                """),
            Example("""
            let int = Int↓
            .init(1.0)
            """):
                Example("""
                let int = Int(1.0)
                """),
            Example("""
            let int = Int↓


            .init(1.0)
            """):
                Example("""
                let int = Int(1.0)
                """),
            Example("""
            let int = Int↓


                  .init(1.0)
            """):
                Example("""
                let int = Int(1.0)
                """),
            Example("""
            let int = Int↓


                  .init(1.0)



            """):
                Example("""
                let int = Int(1.0)



                """)
        ]
    )

    public func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor? {
        Visitor()
    }

    public func makeRewriter(file: SwiftLintFile) -> ViolationsSyntaxRewriter? {
        file.locationConverter.map { locationConverter in
            Rewriter(
                locationConverter: locationConverter,
                disabledRegions: disabledRegions(file: file)
            )
        }
    }
}

private extension ExplicitInitRule {
    final class Visitor: SyntaxVisitor, ViolationsSyntaxVisitor {
        private(set) var violationPositions: [AbsolutePosition] = []

        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard
                let calledExpression = node.calledExpression.as(MemberAccessExprSyntax.self),
                let calledBase = calledExpression.base?.as(IdentifierExprSyntax.self),
                calledBase.identifier.text.first?.isUppercase == true,
                calledExpression.name.text == "init",
                let violationPosition = calledExpression.base?.endPositionBeforeTrailingTrivia
            else {
                return
            }

            violationPositions.append(violationPosition)
        }
    }

    final class Rewriter: SyntaxRewriter, ViolationsSyntaxRewriter {
        private(set) var correctionPositions: [AbsolutePosition] = []
        let locationConverter: SourceLocationConverter
        let disabledRegions: [SourceRange]

        init(locationConverter: SourceLocationConverter, disabledRegions: [SourceRange]) {
            self.locationConverter = locationConverter
            self.disabledRegions = disabledRegions
        }

        override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
            guard
                let calledExpression = node.calledExpression.as(MemberAccessExprSyntax.self),
                let calledBase = calledExpression.base?.as(IdentifierExprSyntax.self),
                calledBase.identifier.text.first?.isUppercase == true,
                calledExpression.name.text == "init",
                let violationPosition = calledExpression.base?.endPositionBeforeTrailingTrivia,
                !isInDisabledRegion(node)
            else {
                return super.visit(node)
            }

            correctionPositions.append(violationPosition)

            let newNode = node.withCalledExpression(
                ExprSyntax(
                    IdentifierExprSyntax {
                        $0.useIdentifier(calledBase.identifier)
                    }
                )
            )

            return super.visit(newNode)
        }

        private func isInDisabledRegion<T: SyntaxProtocol>(_ node: T) -> Bool {
            disabledRegions.contains { region in
                region.contains(node.positionAfterSkippingLeadingTrivia, locationConverter: locationConverter)
            }
        }
    }
}
