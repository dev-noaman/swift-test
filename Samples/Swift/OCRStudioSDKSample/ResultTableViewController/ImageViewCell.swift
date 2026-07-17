/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

import UIKit

class ImageViewCell:UITableViewCell {
  var fieldName : FieldNameLabel!
  var imageFieldView : UIImageView!
  
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    fieldName = FieldNameLabel()
    imageFieldView = UIImageView()
    
    contentView.addSubview(fieldName)
    contentView.addSubview(imageFieldView)
    
    fieldName.translatesAutoresizingMaskIntoConstraints = false
    fieldName.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
    fieldName.heightAnchor.constraint(equalToConstant: 20).isActive = true
    fieldName.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5).isActive = true
    fieldName.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5).isActive = true
	fieldName.font = UIFont(name: "Menlo-Regular", size: 14)
		
	imageFieldView.translatesAutoresizingMaskIntoConstraints = false
	imageFieldView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10).isActive = true
	imageFieldView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10).isActive = true
	imageFieldView.topAnchor.constraint(equalTo: fieldName.bottomAnchor, constant: 5).isActive = true
	imageFieldView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
    imageFieldView.contentMode = .scaleAspectFit
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
  }
}
