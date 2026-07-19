// Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
//
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit

@objc(SFSDKViewControllerConfig)
@objcMembers public class SFSDKViewControllerConfig: NSObject {

    /// Specify the font to use for navigation bar header text.
    @objc public var navBarFont: UIFont?

    /// Specify the text color to use for navigation bar header text.
    @objc public var navBarTintColor: UIColor?

    /// Specify navigation bar color. This color will be used by the view header.
    @objc public var navBarColor: UIColor?

    /// Specify navigation bar title color. This color will be used by the view header.
    @objc public var navBarTitleColor: UIColor?

    // MARK: - Swift-name compatibility
    //
    // Prior SDK releases surfaced these properties to Swift under longer names via `NS_SWIFT_NAME`
    // on the Objective-C interface (e.g. `navBarColor NS_SWIFT_NAME(navigationBarColor)`). The
    // ObjC→Swift migration re-declared them using the shorter ObjC identifiers, dropping the
    // historical Swift spellings. These `@nonobjc` computed aliases restore source compatibility for
    // Swift consumers (and the sample apps); they forward to the primary stored properties.

    @nonobjc public var navigationBarFont: UIFont? {
        get { navBarFont }
        set { navBarFont = newValue }
    }

    @nonobjc public var navigationBarColor: UIColor? {
        get { navBarColor }
        set { navBarColor = newValue }
    }

    @nonobjc public var navigationTitleColor: UIColor? {
        get { navBarTitleColor }
        set { navBarTitleColor = newValue }
    }
}
