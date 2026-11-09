// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 dongx
import Foundation
import CoreGraphics

// The card body defines the hit area; the trailing hint does not enlarge it.
// Prefer the largest overlap, then the nearest row when several rows overlap equally.
func overlappingTarget(for card: CGRect, targets: [CGRect]) -> Int? {
    var best: (index: Int, area: CGFloat, distance: CGFloat)?
    for (index, frame) in targets.enumerated() {
        let intersection = card.intersection(frame)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { continue }
        let area = intersection.width * intersection.height
        let distance = abs(card.midY - frame.midY)
        if best == nil || area > best!.area || (area == best!.area && distance < best!.distance) {
            best = (index, area, distance)
        }
    }
    return best?.index
}
