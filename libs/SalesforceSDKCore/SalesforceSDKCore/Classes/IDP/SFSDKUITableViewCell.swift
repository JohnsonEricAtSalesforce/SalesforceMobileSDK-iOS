/*
 SFSDKUITableViewCell.swift
 SalesforceSDKCore

 Created by Raj Rao on 6/05/18.

 Copyright (c) 2018-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit

private let kHorizontalSpace: CGFloat = 12
private let kImageWidth: CGFloat = 60
private let kImageHeight: CGFloat = 60

@objc(SFSDKUITableViewCell)
public class SFSDKUITableViewCell: UITableViewCell {

    private var titleLabel: UILabel!
    private var detailLabel: UILabel!
    private var profileImageView: UIImageView!

    @objc public var userName: String? {
        get { return titleLabel.text }
        set { titleLabel.text = newValue }
    }

    @objc public var hostName: String? {
        get { return detailLabel.text }
        set { detailLabel.text = newValue }
    }

    @objc public var imageURL: URL?

    @objc public var profileImage: UIImage? {
        didSet {
            if let image = profileImage {
                let resizedImage = SFSDKUITableViewCell.resizeImage(image, size: CGSize(width: kImageWidth, height: kImageHeight))
                profileImageView.image = resizedImage
            }
        }
    }

    @objc public class var reuseCellIdentifier: String {
        return "sfsdkusercellview"
    }

    @objc public class var cellHeight: CGFloat {
        return 123
    }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.backgroundColor = UIColor.salesforceSystemBackgroundColor

        let pimage = SFSDKResourceUtils.imageNamed("profile-placeholder")
        let image = SFSDKUITableViewCell.resizeImage(pimage, size: CGSize(width: kImageWidth, height: kImageHeight))

        layer.borderWidth = kHorizontalSpace / 2
        updateLayerColor()

        profileImageView = UIImageView(image: image)
        profileImageView.backgroundColor = .gray
        profileImageView.bounds = CGRect(x: 0, y: 0, width: kImageWidth, height: kImageHeight)
        profileImageView.image = image
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        profileImageView.layer.masksToBounds = true
        profileImageView.clipsToBounds = true

        titleLabel = UILabel()
        detailLabel = UILabel()
        titleLabel.font = UIFont.sfsdk_textRegular(16.0)
        titleLabel.textColor = UIColor.salesforceLabelColor
        detailLabel.font = UIFont.sfsdk_textRegular(14.0)
        detailLabel.textColor = UIColor.salesforceLabelColor

        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(profileImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            profileImageView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 12),
            profileImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.leftAnchor.constraint(equalTo: profileImageView.rightAnchor, constant: 12),
            titleLabel.lastBaselineAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -3),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.leftAnchor.constraint(equalTo: profileImageView.rightAnchor, constant: 12)
        ])
    }

    private func updateLayerColor() {
        layer.borderColor = UIColor.salesforceSystemBackgroundColor.cgColor
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateLayerColor()
        }
    }

    @objc public class func resizeImage(_ image: UIImage?, size: CGSize) -> UIImage? {
        guard let image = image else { return nil }
        let rect = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
        UIGraphicsBeginImageContext(rect.size)
        image.draw(in: rect)
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
