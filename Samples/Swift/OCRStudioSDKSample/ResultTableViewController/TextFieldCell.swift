/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

import UIKit

class TextFieldCell: UITableViewCell {
  var fieldName : FieldNameLabel!
  var resultTextView : UITextView!
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    resultTextView = UITextView()
    fieldName = FieldNameLabel()
    
    contentView.addSubview(fieldName)
    contentView.addSubview(resultTextView)
    
    fieldName.translatesAutoresizingMaskIntoConstraints = false
    fieldName.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5).isActive = true
    fieldName.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5).isActive = true
    fieldName.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
    fieldName.heightAnchor.constraint(equalToConstant: 20).isActive = true
    fieldName.font = UIFont(name: "Menlo-Regular", size: 16)
    fieldName.textColor = UIColor.darkGray
    
    resultTextView.translatesAutoresizingMaskIntoConstraints = false
    resultTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5).isActive = true
    resultTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5).isActive = true
    resultTextView.topAnchor.constraint(equalTo: fieldName.bottomAnchor, constant: 5).isActive = true
    resultTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 5).isActive = true
    resultTextView.font = UIFont(name: "Menlo-Regular", size: 14)
    resultTextView.contentInset = .zero
    
    resultTextView.isEditable = false
    resultTextView.backgroundColor = .clear
    resultTextView.isScrollEnabled = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
  }
}
