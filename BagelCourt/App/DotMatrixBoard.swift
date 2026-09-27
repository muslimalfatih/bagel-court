import SwiftUI

/// The tourney.social courtside board: text drawn as lit ivory dots on a grid of unlit ones.
/// Knows digits, the en dash and the letters the scoreboard uses (DEUCE, AD IN, AD OUT, FINAL);
/// anything else draws as a blank. Changes instantly, like a real LED board.
struct DotMatrixBoard: View {
    let text: String
    var columns = 37   // six characters plus a margin

    private static let rows = 7

    var body: some View {
        Canvas { ctx, size in
            let pitch = min(size.width / CGFloat(columns), size.height / CGFloat(Self.rows))
            let dot = pitch * 0.72
            let lit = Self.litCells(for: text, columns: columns)
            for row in 0..<Self.rows {
                for col in 0..<columns {
                    let rect = CGRect(x: CGFloat(col) * pitch + (pitch - dot) / 2,
                                      y: CGFloat(row) * pitch + (pitch - dot) / 2,
                                      width: dot, height: dot)
                    let on = lit.contains(row * columns + col)
                    ctx.fill(Path(ellipseIn: rect), with: .color(on ? .bcText : .bcBorder))
                }
            }
        }
        .aspectRatio(CGFloat(columns) / CGFloat(Self.rows), contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(text)
    }

    /// Indices (row × columns + column) of the lit dots, with the text centred.
    static func litCells(for text: String, columns: Int) -> Set<Int> {
        let chars = Array(text.uppercased())
        let width = chars.count * 6 - 1                  // 5 columns per glyph, 1 between glyphs
        var col = max(0, (columns - width) / 2)
        var lit = Set<Int>()
        for ch in chars {
            if let glyph = glyphs[ch] {
                for (row, line) in glyph.enumerated() {
                    for (x, bit) in line.enumerated() where bit == "1" && col + x < columns {
                        lit.insert(row * columns + col + x)
                    }
                }
            }
            col += 6
        }
        return lit
    }

    /// 5 × 7 glyphs, one string per row.
    private static let glyphs: [Character: [String]] = [
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        "–": ["00000", "00000", "00000", "01110", "00000", "00000", "00000"],
        "-": ["00000", "00000", "00000", "01110", "00000", "00000", "00000"],
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
        "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    ]
}
