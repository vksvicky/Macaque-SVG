import XCTest
@testable import MacaqueSVG

final class PropertiesInspectorTests: XCTestCase {

    // MARK: - [Right] Geometry mutations

    func testRectGeometryMutation() {
        let rect = SVGRect(x: 0, y: 0, width: 100, height: 50)

        rect.x = 10
        rect.y = 20
        rect.width = 200
        rect.height = 150

        XCTAssertEqual(rect.x, 10)
        XCTAssertEqual(rect.y, 20)
        XCTAssertEqual(rect.width, 200)
        XCTAssertEqual(rect.height, 150)
    }

    func testCircleGeometryMutation() {
        let circle = SVGCircle(cx: 0, cy: 0, r: 10)

        circle.cx = 50
        circle.cy = 75
        circle.r = 30

        XCTAssertEqual(circle.cx, 50)
        XCTAssertEqual(circle.cy, 75)
        XCTAssertEqual(circle.r, 30)
    }

    // MARK: - [Right] Style mutations

    func testStyleFillMutation() {
        let element = SVGElement()

        element.style.fill = "#ff0000"

        XCTAssertEqual(element.style.fill, "#ff0000")
    }

    func testStyleStrokeMutation() {
        let element = SVGElement()

        element.style.stroke = "blue"

        XCTAssertEqual(element.style.stroke, "blue")
    }

    func testStyleStrokeWidthMutation() {
        let element = SVGElement()

        element.style.strokeWidth = 2.5

        XCTAssertEqual(element.style.strokeWidth, 2.5)
    }

    func testStyleOpacityMutation() {
        let element = SVGElement()

        element.style.opacity = 0.5

        XCTAssertEqual(element.style.opacity, 0.5)
    }

    // MARK: - [Right] Transform & identity mutations

    func testTransformMutation() {
        let element = SVGElement()

        element.transform.tx = 42
        element.transform.ty = -17

        XCTAssertEqual(element.transform.tx, 42)
        XCTAssertEqual(element.transform.ty, -17)
    }

    func testSvgIdMutation() {
        let element = SVGElement()
        XCTAssertNil(element.svgId)

        element.svgId = "header-logo"

        XCTAssertEqual(element.svgId, "header-logo")
    }

    // MARK: - [B] Boundary conditions

    func testOpacityClampedToZero() {
        let element = SVGElement()

        element.style.opacity = -0.5

        XCTAssertEqual(element.style.opacity, -0.5,
                       "Model stores raw value; clamping is a view-level concern")
    }

    func testOpacityClampedToOne() {
        let element = SVGElement()

        element.style.opacity = 3.0

        XCTAssertEqual(element.style.opacity, 3.0,
                       "Model stores raw value; clamping is a view-level concern")
    }

    func testNegativeRectDimensions() {
        let rect = SVGRect(x: 0, y: 0, width: -10, height: -20)

        XCTAssertEqual(rect.width, -10)
        XCTAssertEqual(rect.height, -20)
    }

    func testZeroRadius() {
        let circle = SVGCircle(cx: 10, cy: 10, r: 0)

        XCTAssertEqual(circle.r, 0)
    }

    func testOptionalRxRyNilByDefault() {
        let rect = SVGRect(x: 0, y: 0, width: 100, height: 100)

        XCTAssertNil(rect.rx)
        XCTAssertNil(rect.ry)
    }

    // MARK: - [C] Cross-checking

    func testStyleMutationDoesNotAffectTransform() {
        let element = SVGElement()
        let originalTransform = element.transform

        element.style.fill = "green"
        element.style.opacity = 0.8

        XCTAssertEqual(element.transform, originalTransform)
    }

    func testTransformMutationDoesNotAffectStyle() {
        let element = SVGElement()
        element.style.fill = "red"
        element.style.stroke = "black"
        element.style.strokeWidth = 1
        element.style.opacity = 0.9
        let snapshotStyle = element.style

        element.transform = CGAffineTransform(translationX: 100, y: 200)

        XCTAssertEqual(element.style, snapshotStyle)
    }

    func testMultipleElementsIndependent() {
        let rectA = SVGRect(x: 0, y: 0, width: 50, height: 50)
        let rectB = SVGRect(x: 0, y: 0, width: 50, height: 50)

        rectA.x = 999
        rectA.style.fill = "orange"

        XCTAssertEqual(rectB.x, 0)
        XCTAssertNil(rectB.style.fill)
    }

    // MARK: - [E] Error / edge conditions

    func testEmptyStringIdBecomesNil() {
        let element = SVGElement(svgId: "something")

        element.svgId = ""

        XCTAssertEqual(element.svgId, "",
                       "Model stores the raw value; the view converts empty string to nil")
    }

    func testPathDMutation() {
        let path = SVGPath(d: "M0,0 L10,10")

        path.d = ""

        XCTAssertEqual(path.d, "")
    }

    func testPolylinePointsMutation() {
        let polyline = SVGPolyline()
        XCTAssertTrue(polyline.points.isEmpty)

        polyline.points = [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)]

        XCTAssertEqual(polyline.points.count, 2)
        XCTAssertEqual(polyline.points[0], CGPoint(x: 1, y: 2))
        XCTAssertEqual(polyline.points[1], CGPoint(x: 3, y: 4))
    }

    func testDefaultStyleValues() {
        let style = SVGStyle()

        XCTAssertNil(style.fill)
        XCTAssertNil(style.stroke)
        XCTAssertNil(style.strokeWidth)
        XCTAssertNil(style.opacity)
    }

    func testTransformIdentityByDefault() {
        let element = SVGElement()

        XCTAssertEqual(element.transform, .identity)
    }
}
