/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

import Foundation

class DocTypeCell : UITableViewCell {
  
  var labelDocType : UILabel!
  
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    labelDocType = UILabel()
    addSubview(labelDocType)
    
    labelDocType.translatesAutoresizingMaskIntoConstraints = false
    labelDocType.topAnchor.constraint(equalTo: topAnchor, constant: 5).isActive = true
    labelDocType.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5).isActive = true
    labelDocType.leftAnchor.constraint(equalTo: leftAnchor, constant: 5).isActive = true
    labelDocType.rightAnchor.constraint(equalTo: rightAnchor, constant: -5).isActive = true
    labelDocType.textAlignment = .center
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
