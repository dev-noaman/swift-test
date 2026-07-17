/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

import Foundation

class DocTypesListController : UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
  
  weak var delegateSampSID : SampleViewControllerProtocol?
	
	var searchBar : UISearchBar = {
		let searchbar = UISearchBar()
		searchbar.translatesAutoresizingMaskIntoConstraints = false
    searchbar.autocapitalizationType = UITextAutocapitalizationType.none
		return searchbar
	}()
	
  let docTypestableView : UITableView = {
    let tableView = UITableView()
    tableView.register(DocTypeCell.self, forCellReuseIdentifier: "DocTypeCell")
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.estimatedRowHeight = 100
    return tableView
  }()
  
  var modesList = [String]()
  var masksList = [[String]]()
    
  var sectionsList = [String]()
  var tableArray = [[String]]()
    
	func numberOfSections(in tableView: UITableView) -> Int {
		return sectionsList.count
	}
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return sectionsList[section]
	}
	
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tableArray[section].count
  }
      
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "DocTypeCell", for: indexPath) as! DocTypeCell
    cell.labelDocType.text = tableArray[indexPath.section][indexPath.row]
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    delegateSampSID?.setTargetGroupAndMask(
        targetGroup: sectionsList[indexPath.section],
        targetMask: tableArray[indexPath.section][indexPath.row])
    self.dismiss(animated: true, completion: nil)
  }
  
  func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
    // noop
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 40
  }
	
  func searchBar(_ searchBar: UISearchBar, textDidChange text: String) {

		if text.isEmpty {
      sectionsList = modesList
      tableArray = masksList
		} else {
            
      sectionsList.removeAll()
      tableArray.removeAll()
      
      for mode in modesList {
        if(mode.contains(text)) {
            tableArray.append(masksList[modesList.index(of: mode)!])
            sectionsList.append(mode)
        } else{
          var fitMasks = [String]()
          
          for mask in masksList[modesList.index(of: mode)!] {
            if mask.contains(text) {
              fitMasks.append(mask)
            }
          }
          
          if fitMasks.count != 0 {
            tableArray.append(fitMasks)
            sectionsList.append(mode)
          }
        }
      }
 
		}
        
		docTypestableView.reloadData()
	}
	
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		self.searchBar.endEditing(true)
	}
  
  init(docTypesList: [String:[String]]) {
    super.init(nibName: nil, bundle: nil)
    
    self.modesList = [String](docTypesList.keys).sorted()
    
    for mode in modesList {
      self.masksList.append(docTypesList[mode]!)
    }

    self.sectionsList = self.modesList
    self.tableArray = self.masksList
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    docTypestableView.delegate = self
    docTypestableView.dataSource = self
		searchBar.delegate = self
		
		view.addSubview(searchBar)
		view.addSubview(docTypestableView)
		
		var safeArea = UILayoutGuide()
		if #available(iOS 11.0, *) {
			safeArea = view.safeAreaLayoutGuide
			searchBar.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 0).isActive = true
			searchBar.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 0).isActive = true
			searchBar.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: 0).isActive = true
			
			docTypestableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 0).isActive = true
			docTypestableView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: 0).isActive = true
			docTypestableView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 0).isActive = true
			docTypestableView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: 0).isActive = true
		} else {
			searchBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
			searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
			searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
			
			docTypestableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 0).isActive = true
			docTypestableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
			docTypestableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
			docTypestableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
		}
		
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
}
