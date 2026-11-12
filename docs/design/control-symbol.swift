// Turns docs/design/control-symbol.svg into an SF Symbols template with all nine weights at all three scales, which
// Xcode compiles from a .symbolset. Run it through `just control-symbol`; the format the source must follow is in the
// SVG's own comment. Script mode on macOS: CoreGraphics strokes each path and merges the pieces into filled outlines,
// which is all a template holds.
//
// Usage: swift docs/design/control-symbol.swift <source.svg> <template.svg>

import CoreGraphics
import Foundation

// MARK: - The template's geometry, from Apple's SF Symbols template at 100 points

/// A column of the template: a weight, how much it scales the Regular stroke widths, and the x of its center.
struct Weight {
    var name: String
    var factor: CGFloat
    var column: CGFloat
}

/// A row of the template: a scale, its baseline, and its Regular glyph's height and side bearing.
struct Scale {
    var name: String
    var label: String
    var baseline: CGFloat
    var height: CGFloat
    var bearing: CGFloat
}

let weights = [
    Weight(name: "Ultralight", factor: 0.35, column: 559.711),
    Weight(name: "Thin", factor: 0.5, column: 856.422),
    Weight(name: "Light", factor: 0.75, column: 1153.13),
    Weight(name: "Regular", factor: 1.0, column: 1449.84),
    Weight(name: "Medium", factor: 1.1, column: 1746.56),
    Weight(name: "Semibold", factor: 1.2, column: 2043.27),
    Weight(name: "Bold", factor: 1.3, column: 2339.98),
    Weight(name: "Heavy", factor: 1.45, column: 2636.69),
    Weight(name: "Black", factor: 1.6, column: 2933.4),
]

/// Heights and side bearings match `lightbulb.fill` at Regular.
let scales = [
    Scale(name: "S", label: "Small", baseline: 696, height: 90, bearing: 10),
    Scale(name: "M", label: "Medium", baseline: 1126, height: 113, bearing: 12.5),
    Scale(name: "L", label: "Large", baseline: 1556, height: 146, bearing: 16),
]

/// The height of a capital H, which every row's capline sits above its baseline.
let capHeight: CGFloat = 70.459
/// Where the Regular glyph's center sits, above the baseline: a little over half the cap height, like `lightbulb.fill`.
let centerAboveBaseline: CGFloat = 37

// MARK: - Reading the source

/// One `<path>` of the source: its outline, whether it's filled, its Regular stroke width, and whether it cuts out.
struct SourcePath {
    var outline: CGPath
    var filled: Bool
    var strokeWidth: CGFloat?
    var cuts: Bool
}

enum SymbolError: Error, CustomStringConvertible {
    case usage
    case unreadable(String)
    case badPath(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: swift control-symbol.swift <source.svg> <template.svg>"
        case .unreadable(let file):
            return "can't read \(file)"
        case .badPath(let reason):
            return "bad path data: \(reason)"
        }
    }
}

/// Collects every `<path>` element's attributes, in document order.
final class PathCollector: NSObject, XMLParserDelegate {
    var attributes: [[String: String]] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "path" {
            attributes.append(attributeDict)
        }
    }
}

/// Parses path data with absolute M, L, H, V, C, circular A and Z, the only commands the source uses.
func parsePathData(_ data: String) throws -> CGPath {
    let tokenPattern = try NSRegularExpression(pattern: "[A-Za-z]|-?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?")
    let range = NSRange(data.startIndex..., in: data)
    var tokens = tokenPattern.matches(in: data, range: range).compactMap { match in
        Range(match.range, in: data).map { String(data[$0]) }
    }
    tokens.reverse()

    func number() throws -> CGFloat {
        guard let token = tokens.popLast(), let value = Double(token) else {
            throw SymbolError.badPath("expected a number in \"\(data)\"")
        }
        return CGFloat(value)
    }

    let path = CGMutablePath()
    var command = ""
    while let next = tokens.last {
        if Double(next) == nil {
            command = next
            tokens.removeLast()
        }
        let current = path.isEmpty ? CGPoint.zero : path.currentPoint
        switch command {
        case "M":
            path.move(to: CGPoint(x: try number(), y: try number()))
            command = "L"
        case "L":
            path.addLine(to: CGPoint(x: try number(), y: try number()))
        case "H":
            path.addLine(to: CGPoint(x: try number(), y: current.y))
        case "V":
            path.addLine(to: CGPoint(x: current.x, y: try number()))
        case "C":
            let control1 = CGPoint(x: try number(), y: try number())
            let control2 = CGPoint(x: try number(), y: try number())
            path.addCurve(to: CGPoint(x: try number(), y: try number()), control1: control1, control2: control2)
        case "A":
            try addArc(to: path, from: current, readingFrom: number)
        case "Z":
            path.closeSubpath()
        default:
            throw SymbolError.badPath("unsupported command \"\(command)\" (use absolute M, L, H, V, C, A or Z)")
        }
    }
    return path
}

/// Adds an SVG arc, converted from its endpoints to a center (SVG 1.1, appendix F.6.5). Circular arcs only.
func addArc(to path: CGMutablePath, from start: CGPoint, readingFrom number: () throws -> CGFloat) throws {
    let radiusX = try number()
    let radiusY = try number()
    let rotation = try number()
    let largeArc = try number() != 0
    let sweep = try number() != 0
    let end = CGPoint(x: try number(), y: try number())
    guard radiusX == radiusY, rotation == 0 else {
        throw SymbolError.badPath("only circular arcs without rotation are supported")
    }
    let halfX = (start.x - end.x) / 2
    let halfY = (start.y - end.y) / 2
    let halfSquared = halfX * halfX + halfY * halfY
    let radius = max(radiusX, sqrt(halfSquared))
    let sign: CGFloat = largeArc == sweep ? -1 : 1
    let coefficient = sign * sqrt(max(0, (radius * radius - halfSquared) / halfSquared))
    let center = CGPoint(
        x: coefficient * halfY + (start.x + end.x) / 2,
        y: -coefficient * halfX + (start.y + end.y) / 2
    )
    // With y pointing down, as in SVG, a positive sweep runs toward increasing angles, which CoreGraphics calls
    // counterclockwise.
    path.addArc(
        center: center,
        radius: radius,
        startAngle: atan2(start.y - center.y, start.x - center.x),
        endAngle: atan2(end.y - center.y, end.x - center.x),
        clockwise: !sweep
    )
}

func readSource(_ file: String) throws -> [SourcePath] {
    guard let parser = XMLParser(contentsOf: URL(fileURLWithPath: file)) else {
        throw SymbolError.unreadable(file)
    }
    let collector = PathCollector()
    parser.delegate = collector
    guard parser.parse() else {
        throw SymbolError.unreadable(file)
    }
    return try collector.attributes.map { attributes in
        SourcePath(
            outline: try parsePathData(attributes["d"] ?? ""),
            filled: (attributes["fill"] ?? "black") != "none",
            strokeWidth: attributes["stroke-width"].flatMap(Double.init).map { CGFloat($0) },
            cuts: (attributes["class"] ?? "").split(separator: " ").contains("cut")
        )
    }
}

// MARK: - Drawing a glyph

/// The glyph at one weight, in the source's coordinates: each path's fill and stroke, added or cut out in order.
func glyph(of source: [SourcePath], weightFactor: CGFloat) -> CGPath {
    var result: CGPath = CGMutablePath()
    for piece in source {
        var shape: CGPath = piece.filled ? piece.outline : CGMutablePath()
        if let width = piece.strokeWidth {
            // A cut thins less than a stroke thickens, so the filament stays open at heavy weights.
            let scaledWidth = width * (piece.cuts ? sqrt(weightFactor) : weightFactor)
            let stroke = piece.outline.copy(
                strokingWithWidth: scaledWidth,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )
            shape = shape.union(stroke)
        }
        result = piece.cuts ? result.subtracting(shape) : result.union(shape)
    }
    return result
}

/// A number for the template, with three decimals at most.
func svgNumber(_ value: CGFloat) -> String {
    var text = String(format: "%.3f", Double(value))
    while text.hasSuffix("0") {
        text.removeLast()
    }
    if text.hasSuffix(".") {
        text.removeLast()
    }
    return text == "-0" ? "0" : text
}

/// Path data for the template.
func svgPathData(_ path: CGPath) -> String {
    func format(_ point: CGPoint) -> String {
        "\(svgNumber(point.x)) \(svgNumber(point.y))"
    }
    var commands: [String] = []
    path.applyWithBlock { element in
        let points = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint:
            commands.append("M\(format(points[0]))")
        case .addLineToPoint:
            commands.append("L\(format(points[0]))")
        case .addQuadCurveToPoint:
            commands.append("Q\(format(points[0])) \(format(points[1]))")
        case .addCurveToPoint:
            commands.append("C\(format(points[0])) \(format(points[1])) \(format(points[2]))")
        case .closeSubpath:
            commands.append("Z")
        @unknown default:
            break
        }
    }
    return commands.joined()
}

// MARK: - Writing the template

let guideStyle = "fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;"
let marginStyle = "fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;"
let textStyle = "stroke:none;fill:black;font-family:sans-serif;font-size:13;"

func line(id: String?, style: String, from start: CGPoint, to end: CGPoint) -> String {
    let idAttribute = id.map { " id=\"\($0)\"" } ?? ""
    return "  <line\(idAttribute) style=\"\(style)\" x1=\"\(svgNumber(start.x))\" x2=\"\(svgNumber(end.x))\" "
        + "y1=\"\(svgNumber(start.y))\" y2=\"\(svgNumber(end.y))\"/>"
}

func text(_ content: String, at point: CGPoint, style: String = "") -> String {
    "  <text style=\"\(textStyle)\(style)\" transform=\"matrix(1 0 0 1 \(svgNumber(point.x)) \(svgNumber(point.y)))\">"
        + "\(content)</text>"
}

/// The glyph at one weight and scale, as its group under Symbols and its two margins under Guides. Every weight at a
/// scale takes the same scaling and vertical place, from the Regular glyph's box, so heavier ones grow around it.
func cell(of source: [SourcePath], weight: Weight, scale: Scale, regular: CGRect) -> (symbol: String, margins: String) {
    let ratio = scale.height / regular.height
    var toScale = CGAffineTransform(scaleX: ratio, y: ratio)
    let scaled = glyph(of: source, weightFactor: weight.factor).copy(using: &toScale) ?? CGMutablePath()
    let box = scaled.boundingBoxOfPath
    var place = CGAffineTransform(
        translationX: scale.bearing - box.minX, y: -centerAboveBaseline - regular.midY * ratio)
    let local = scaled.copy(using: &place) ?? CGMutablePath()
    let advance = box.width + 2 * scale.bearing
    let left = weight.column - advance / 2
    let id = "\(weight.name)-\(scale.name)"
    let margins = [("left", left), ("right", left + advance)].map { side, edge in
        line(
            id: "\(side)-margin-\(id)",
            style: marginStyle,
            from: CGPoint(x: edge, y: scale.baseline - 120),
            to: CGPoint(x: edge, y: scale.baseline + 30)
        )
    }
    let symbol =
        "  <g id=\"\(id)\" transform=\"matrix(1 0 0 1 \(svgNumber(left)) \(svgNumber(scale.baseline)))\">\n"
        + "   <path class=\"monochrome-0 multicolor-0:tintColor hierarchical-0:primary SFSymbolsPreviewWireframe\" "
        + "d=\"\(svgPathData(local))\"/>\n  </g>"
    return (symbol, margins.joined(separator: "\n"))
}

/// The labels around the glyphs, as in Apple's template, including the template version that Xcode reads.
func notes() -> [String] {
    let artboard =
        "  <rect height=\"2200\" id=\"artboard\" style=\"fill:white;opacity:1\" width=\"3300\" x=\"0\" y=\"0\"/>"
    let rule = "fill:none;stroke:black;opacity:1;stroke-width:0.5;"
    return [
        artboard,
        line(id: nil, style: rule, from: CGPoint(x: 263, y: 292), to: CGPoint(x: 3036, y: 292)),
        text("Weight/Scale Variations", at: CGPoint(x: 263, y: 322), style: "font-weight:bold;"),
    ]
        + weights.map { text($0.name, at: CGPoint(x: $0.column, y: 322), style: "text-anchor:middle;") }
        + scales.map { text($0.label, at: CGPoint(x: 263, y: $0.baseline + 30)) }
        + [
            line(id: nil, style: rule, from: CGPoint(x: 263, y: 1903), to: CGPoint(x: 3036, y: 1903)),
            text("Design Variations", at: CGPoint(x: 263, y: 1953), style: "font-weight:bold;"),
            text("Template v.3.0", at: CGPoint(x: 3036, y: 1933), style: "text-anchor:end;"),
            text("Requires Xcode 13 or greater", at: CGPoint(x: 3036, y: 1951), style: "text-anchor:end;"),
            text("Generated by `just control-symbol`", at: CGPoint(x: 3036, y: 1969), style: "text-anchor:end;"),
            text("Typeset at 100 points", at: CGPoint(x: 3036, y: 1987), style: "text-anchor:end;"),
        ]
}

func template(of source: [SourcePath]) -> String {
    let regular = glyph(of: source, weightFactor: 1).boundingBoxOfPath
    var guides: [String] = []
    var symbols: [String] = []
    for scale in scales {
        let capline = scale.baseline - capHeight
        guides += [
            line(
                id: "Baseline-\(scale.name)",
                style: guideStyle,
                from: CGPoint(x: 263, y: scale.baseline),
                to: CGPoint(x: 3036, y: scale.baseline)
            ),
            line(
                id: "Capline-\(scale.name)",
                style: guideStyle,
                from: CGPoint(x: 263, y: capline),
                to: CGPoint(x: 3036, y: capline)
            ),
        ]
        for weight in weights {
            let (symbol, margins) = cell(of: source, weight: weight, scale: scale, regular: regular)
            symbols.append(symbol)
            guides.append(margins)
        }
    }
    return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
        <svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" \
        width="3300" height="2200">
         <!-- Generated by `just control-symbol` from docs/design/control-symbol.svg. Don't edit by hand. -->
         <style>.SFSymbolsPreviewWireframe {fill:none;opacity:1.0;stroke:black;stroke-width:0.5}
        </style>
         <g id="Notes">
        \(notes().joined(separator: "\n"))
         </g>
         <g id="Guides">
        \(guides.joined(separator: "\n"))
         </g>
         <g id="Symbols">
        \(symbols.joined(separator: "\n"))
         </g>
        </svg>

        """
}

// MARK: - Main

do {
    let arguments = CommandLine.arguments
    guard arguments.count == 3 else {
        throw SymbolError.usage
    }
    let source = try readSource(arguments[1])
    try template(of: source).write(toFile: arguments[2], atomically: true, encoding: .utf8)
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
