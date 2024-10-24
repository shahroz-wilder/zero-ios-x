//
// Copyright 2023, 2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import Foundation
import UniformTypeIdentifiers

struct ImageRoomTimelineItemContent: Hashable {
    let filename: String
    var caption: String?
    var formattedCaption: AttributedString?
    /// The original textual representation of the formatted caption directly from the event (usually HTML code)
    var formattedCaptionHTMLString: String?
    let source: MediaSourceProxy
    let thumbnailSource: MediaSourceProxy?
    var width: CGFloat?
    var height: CGFloat?
    var aspectRatio: CGFloat?
    var blurhash: String?
    var contentType: UTType?
    var isZeroImage = false
    var imageData: Data?
    var imageURL: String?
}
