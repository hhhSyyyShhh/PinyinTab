import Foundation

for row in 1...9 {
    var cells: [String] = []
    for column in 1...row {
        let product = String(format: "%2d", column * row)
        cells.append("\(column)×\(row)=\(product)")
    }
    print(cells.joined(separator: "\t"))
}
