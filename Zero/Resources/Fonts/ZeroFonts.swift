import SwiftUI

public extension Font {
    static let zero = ZeroFonts()
}

public struct ZeroFonts {
    public let bodyXS = Font.caption
    public let bodyXSSemibold = Font.caption.weight(.semibold)
    public let bodySM = Font.footnote
    public let bodySMSemibold = Font.footnote.weight(.semibold)
    public let bodyMD = Font.subheadline
    public let bodyMDSemibold = Font.subheadline.weight(.semibold)
    public let bodyLG = Font.body
    public let bodyLGSemibold = Font.body.weight(.semibold)
    public let headingSM = Font.title3
    public let headingSMSemibold = Font.title3.weight(.semibold)
    public let headingMD = Font.title2
    public let headingMDBold = Font.title2.bold()
    public let headingLG = Font.title
    public let headingLGBold = Font.title.bold()
    public let headingXL = Font.largeTitle
    public let headingXLBold = Font.largeTitle.bold()
}
