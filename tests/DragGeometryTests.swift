// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 dongx
import Foundation
import CoreGraphics

@main struct DragGeometryTests {
    static func main() {
        let rows = [CGRect(x: 0, y: 0, width: 200, height: 36),
                    CGRect(x: 0, y: 40, width: 200, height: 36)]
        // The card enters the sidebar while its cursor can remain outside it.
        assert(overlappingTarget(for: CGRect(x: 190, y: 0, width: 300, height: 30), targets: rows) == 0)
        assert(overlappingTarget(for: CGRect(x: 201, y: 0, width: 300, height: 30), targets: rows) == nil)
        assert(overlappingTarget(for: CGRect(x: 200, y: 0, width: 300, height: 30), targets: rows) == nil)
        assert(overlappingTarget(for: CGRect(x: 100, y: 30, width: 300, height: 40), targets: rows) == 1)
        assert(overlappingTarget(for: CGRect(x: 100, y: 0, width: 300, height: 100), targets: rows) == 1)
        assert(overlappingTarget(for: .zero, targets: rows) == nil)
        assert(overlappingTarget(for: rows[0], targets: []) == nil)
        print("拖动碰撞验证通过：块边缘进入、未相交、边界接触、多分类重叠、空目标")
    }
}
