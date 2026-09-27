import Testing
@testable import BagelCourt

@Suite("Dot-matrix board")
@MainActor
struct DotMatrixBoardTests {

    @Test("Text is centred and each glyph lights its dots")
    func centredGlyph() {
        // "1" is five columns wide, so in a seven-column board it starts at column 1.
        let lit = DotMatrixBoard.litCells(for: "1", columns: 7)
        #expect(lit.contains(3))        // top of the stem: row 0, column 1 + 2
        #expect(!lit.contains(0))       // the left margin stays dark
        #expect(lit.count == 10)        // the "1" glyph has ten dots
    }

    @Test("Unknown characters draw as blanks")
    func unknownCharacter() {
        #expect(DotMatrixBoard.litCells(for: "?", columns: 7).isEmpty)
    }
}
