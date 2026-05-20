import Foundation
let str = "Hello\r\nWorld\r\n"
let lines = str.components(separatedBy: .newlines)
for line in lines {
    print("Line: \(line.debugDescription)")
}
