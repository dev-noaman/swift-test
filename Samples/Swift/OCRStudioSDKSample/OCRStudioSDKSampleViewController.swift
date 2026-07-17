/**
  Copyright (c) 2024-2026, OCR Studio
  All rights reserved.
*/

import UIKit
#if __RFID__
import NFCPassportReader
#endif

protocol SampleViewControllerProtocol : class {
  func setTargetGroupAndMask(targetGroup: String, targetMask: String)
}

class SampleViewController: UIViewController,
                            UIImagePickerControllerDelegate,
                            UINavigationControllerDelegate,
                            SampleViewControllerProtocol,
                            OCRStudioSDKInitializationDelegate {
  var currentDocumenttypeMask : String?
  
  func setTargetGroupAndMask(targetGroup: String, targetMask: String) {
    ocrController.sessionParams().setTargetGroupType(targetGroup)
    self.currentDocumenttypeMask = targetGroup + " : " + targetMask
    
    ocrController.sessionParams().clearTargetMasks()
    ocrController.sessionParams().addTargetMask(targetMask)
    
    ocrController.configureDocumentTypeLabel(self.currentDocumenttypeMask!)
    print("Current mode is \(targetGroup), doc type mask is \(targetMask)")

    ocrController.sessionParams().clearOptions()
    ocrController.sessionParams().setOptionWithName("sessionTimeout", to: "5.0")

    ocrController.setRoiWithOffsetX(0.0, andY: 0.0, orientation: UIDeviceOrientation.portrait, displayRoi: false)
    ocrController.shouldDisplayRoi = false

  }
  
  // Gallery-related
  
  let photoLibraryImagePicker : UIImagePickerController = {
    let picker = UIImagePickerController()
    if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary) {
      picker.sourceType = .photoLibrary
      picker.modalPresentationStyle = .fullScreen
    }
    return picker
  }()
  
  // Photo-related
  
  let photoCameraImagePicker : UIImagePickerController = {
    let picker = UIImagePickerController()
    if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera) {
      picker.sourceType = .camera
      picker.modalPresentationStyle = .fullScreen
    }
    return picker
  }()
  
  
  // Selfie-related
  
  var currentPhotoImage : OBJCOCRStudioSDKImage? = nil;
  
  func reinitSelfieButton() {
    self.selfieButton.isEnabled = false
    self.selfieButton.isHidden = true
    self.currentPhotoImage = nil;
  }
  
  let selfieImagePicker : UIImagePickerController = {
    let picker = UIImagePickerController()
    if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera) {
      picker.sourceType = UIImagePickerController.SourceType.camera
      picker.modalPresentationStyle = .fullScreen
      picker.cameraFlashMode = .off
      picker.cameraDevice = .front
      picker.cameraCaptureMode = .photo
    }
    return picker
  }()
  
  // View-related
  
  var pickerImageActivityIndicator:UIActivityIndicatorView!
  var pickerImageActivityIndicatorContainer:UIView!
  var pickerIAIContainerBackground:UIView!
  
  var docTypeListViewController : DocTypesListController!
    
  var resultTableView : UITableView = {
    var resultTableView = UITableView()
    resultTableView.register(TextFieldCell.self, forCellReuseIdentifier: "TextCell")
    resultTableView.register(ImageViewCell.self, forCellReuseIdentifier: "ImageCell")
    resultTableView.estimatedRowHeight = 100
    resultTableView.translatesAutoresizingMaskIntoConstraints = false
    return resultTableView
  }()
    
  func setTableViewAnchors() {
    if #available(iOS 11.0, *) {
      resultTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
      resultTableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
      resultTableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
      resultTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50).isActive = true
    } else {
      resultTableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
      resultTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
      resultTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
      resultTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50).isActive = true
    }
    resultTableView.estimatedRowHeight = 600
    resultTableView.allowsSelection = false
  }
    
  private var resultTextFields = [(fieldName: String, value: String)]()
  private var resultImageFields = [(fieldName: String, value: UIImage)]()
  private var resultTableFields = [(fieldName: String, value: String)]()

#if __RFID__ //Variables related to RFID reading - start
  private let mrzDataKeys = ["mrz_number", "mrz_cd_number", "mrz_birth_date", "mrz_cd_birth_date", "mrz_expiry_date", "mrz_cd_expiry_date"]
  private var mrzDataDict: [String: String] = [:]
  private var hasRFID = false
  private var mrzkey: String?
  private var isNFCReaderReady = true
  //An instance of the NFCPassportModel class, all information read using NFC is stored here
  private var passport: NFCPassportModel? = nil
  private var doctyperaw: String?
#endif //Variables related to RFID reading - end
    
  func setResult(result: OBJCOCRStudioSDKResultRef, message: String? = nil) {
    resultTextFields.removeAll()
    resultImageFields.removeAll()
    resultTableFields.removeAll()
    
    if (message != nil) {
      resultTextFields.append(("#instruction", message!))
    }
    
    print("Targets count: ", result.targetsCount())
    if result.targetsCount() == 0 {
        resultTextFields.append(("Document not found", "Last session parameters:\n\tSession type: \(ocrController.sessionParams().getSessionType())\n\tTarget Group Type: \(ocrController.sessionParams().getTargetGroupType() )\n\tTarget Masks: \(ocrController.sessionParams().getTargetMasks())"))
    } else {
      for tr_i in 0...result.targetsCount() - 1 {
        let target = result.target(by: tr_i)
        print(result.target(by: tr_i).description())
        var itemTypes : [String] = []
        let data = Data(result.target(by: tr_i).description().utf8)
        do {
          if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let docType = json["specific_type"] as? String {
              resultTextFields.append(("Document type", docType))
#if __RFID__ //Filling docType to generate a JSON string
              self.doctyperaw = docType
#endif
            }
            if let jsonItemTypes = json["item_types"] as? [String] {
              itemTypes = jsonItemTypes
            }
#if __RFID__ //Checking that the recognized document can have an NFC chip by definition
            if let specificTypeHasRFID = json["specific_type_has_rfid"] as? Int {
              if specificTypeHasRFID == 1 {
                self.nfcButton.isHidden = false
                self.nfcButton.isEnabled = true
                hasRFID = true
              } else {
                self.nfcButton.isHidden = true
                self.nfcButton.isEnabled = false
                hasRFID = false
              }
            }
#endif
          }
        } catch let error as NSError {
          print("Failed to load: \(error.localizedDescription)")
        }
        
        for itemType in itemTypes {
          let item_it = target.itemsBegin(itemType)
          let item_end =  target.itemsEnd(itemType)
          while !item_it.isEqual(to: item_end) {
            if itemType == "string" {
              resultTextFields.append((item_it.item().name(), item_it.item().value()))
#if __RFID__ //Mrz parts are extracted from the recognition result to then compose the mrzKey
              if hasRFID {
                if mrzDataKeys.contains(item_it.item().name()) {
                  mrzDataDict[item_it.item().name()] = item_it.item().value()
                }
              }
#endif
            } else if itemType == "image" || itemType == "template" {
              if item_it.item().hasImage() {
                resultImageFields.append((item_it.item().name(), item_it.item().image().convertToUIImage()))
                // Registering photo for selfie check
                if item_it.item().name() == "photo" {
                  if (self.sessionTypesStore.contains("face_matching")) {
                      self.selfieButton.isHidden = false
                      self.selfieButton.isEnabled = true
                      self.currentPhotoImage = item_it.item().image().deepCopy()
                    }
                }
              }
            } else if itemType == "table" {
              resultTableFields.append((item_it.item().name(), item_it.item().value()))
            } else { //new or raw field type
              
            }
            item_it.step()
          }
        }
      }
    }

#if __RFID__ //Creating an mrz key using a recognized document. The key is needed to read the document via NFC using PassportReader
    if hasRFID {
      mrzkey = calculateMrzKey(mrzDataDict: mrzDataDict)
    }
#endif
    
    
    resultTextFields.sort(by: {
        return $0.0 < $1.0
    })
    resultImageFields.sort(by: {
        return $0.0 < $1.0
    })
    
    resultTableFields.sort(by: {
        return $0.0 < $1.0
    })
  }
    
  let cameraButton: UIButton = {
    let button = UIButton(type: .roundedRect)
    button.autoresizingMask = .flexibleWidth
    button.setTitle("...", for: .normal)
    button.isEnabled = false
    button.layer.borderColor = UIColor.blue.cgColor
    return button
  }()
  
  let vauthButton: UIButton = {
    let button = UIButton(type: .roundedRect)
    button.autoresizingMask = .flexibleWidth
    button.setTitle("...", for: .normal)
    button.isEnabled = false
    button.layer.borderColor = UIColor.blue.cgColor
    return button
  }()
                                
  let livenessButton: UIButton = {
    let button = UIButton(type: .roundedRect)
    button.autoresizingMask = .flexibleWidth
    button.setTitle("...", for: .normal)
    button.isEnabled = false
    button.layer.borderColor = UIColor.blue.cgColor
    return button
  }()
    
  let galleryButton: UIButton = {
    let button = UIButton(type: .roundedRect)
    button.autoresizingMask = .flexibleWidth
    button.setTitle("...", for: .normal)
    button.isEnabled = false
    button.layer.borderColor = UIColor.blue.cgColor
    return button
  }()
  
  let photoButton: UIButton = {
    let button = UIButton(type: .roundedRect)
    button.autoresizingMask = .flexibleWidth
    button.setTitle("...", for: .normal)
    button.isEnabled = false
    button.layer.borderColor = UIColor.blue.cgColor
    return button
  }()
    
  let documentListButton: UIButton = {
    let button = UIButton(type: .roundedRect)
    button.autoresizingMask = .flexibleWidth
    button.setTitle("Initializing...", for: .normal)
    button.isEnabled = false
    button.layer.borderColor = UIColor.blue.cgColor
    return button
  }()
    
  let selfieButton : UIButton = {
    let button = UIButton(type: .roundedRect)
    button.autoresizingMask = .flexibleWidth
    button.setTitle("Compare with selfie", for: .normal)
    button.isEnabled = false
    button.isHidden = true
    button.layer.borderColor = UIColor.blue.cgColor
    return button
  }()

  var sessionTypesStore: Array<String> = Array()

#if __RFID__ //NFC reading (using PassportReader) will start when it tapped
  let nfcButton : UIButton = {
    let button = UIButton(type: .roundedRect)
    button.autoresizingMask = .flexibleWidth
    button.setTitle("Read NFC", for: .normal)
    button.isEnabled = false
    button.isHidden = true
    button.layer.borderColor = UIColor.blue.cgColor
    return button
  }()
#endif
  
  let resultTextView: UITextView = {
    let view = UITextView()
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.isEditable = false
    view.font = UIFont(name: "Menlo-Regular", size: 12)
    return view
  }()
    
  let resultImageView: UIImageView = {
    let view = UIImageView()
    view.contentMode = .scaleAspectFit
    view.backgroundColor = UIColor(white: 0.9, alpha: 0.5)
    return view
  }()
                    
  let engineInstance : OCRStudioSDKInstance = {
    // Trial personalized signature (doc/README.md). Validated offline by
    // se::security::internal::VSA → pkcs1_verify against the library-embedded pubkey.
    // Verified by research/verify_static_auth_poc.py (PASS).
    let signature =
      "2122df27f3d5cc5c0cf5ff02e651b2dde1b1dd49bfdd185a192092ee68c674b5" +
      "e138bfbe2e528d6926b5ee234b59929832555359d7a61544a626f04931a4d82f" +
      "727a088dd0ffd73009f28449780a407f74c068de29c7bd7b767f2c8006fae95a" +
      "918782bdb388a7caf492af8f44d3f973da66fc37f73f19f66e71848e93c6556e"
    return OCRStudioSDKInstance(signature: signature)
  }()
  
  func ocrStudioSDKInitialized() {
    self.galleryButton.setTitle("Gallery", for: .normal)
    self.photoButton.setTitle("Photo", for: .normal)
    self.cameraButton.setTitle("Camera", for: .normal)
    self.vauthButton.setTitle("Video authentication", for: .normal)
    self.livenessButton.setTitle("Liveness detection", for: .normal)
    self.documentListButton.setTitle("Select type", for: .normal)
    self.documentListButton.isEnabled = true
    
    self.ocrController.attachEngineInstance(self.engineInstance)
  }
  
  let ocrController: OCRStudioSDKViewController = {
    let ocrController = OCRStudioSDKViewController(lockedOrientation: false, withTorch: false, withBestDevice: true)
    ocrController.modalPresentationStyle = .fullScreen
    ocrController.captureButtonDelegate = ocrController
    
    // configure optional visualization properties (they are NO by default)
    ocrController.displayZonesQuadrangles = true
    ocrController.displayDocumentQuadrangle = true
    ocrController.displayProcessingFeedback = true
    
    return ocrController
  }()
    
  override func viewDidLayoutSubviews() {
    let bottomSafeArea: CGFloat
    let topSafeArea: CGFloat
    
    // safe area for phones with notch
    
    if #available(iOS 11.0, *) {
      bottomSafeArea = view.safeAreaInsets.bottom
      topSafeArea = view.safeAreaInsets.top
    } else {
      bottomSafeArea = bottomLayoutGuide.length
      topSafeArea = topLayoutGuide.length
    }
    
    let buttonHeight: CGFloat = 50
    
    cameraButton.frame = CGRect(x: 0,
                                y: view.bounds.size.height - bottomSafeArea - buttonHeight,
                                width: view.bounds.size.width/4,
                                height: buttonHeight)
    
    galleryButton.frame = CGRect(x: view.bounds.size.width/4,
                                 y: view.bounds.size.height - bottomSafeArea - buttonHeight,
                                 width: view.bounds.size.width/4,
                                 height: buttonHeight)
    
    photoButton.frame = CGRect(x: view.bounds.size.width*2/4,
                                 y: view.bounds.size.height - bottomSafeArea - buttonHeight,
                                 width: view.bounds.size.width/4,
                                 height: buttonHeight)
    
    documentListButton.frame = CGRect(x: view.bounds.size.width*3/4,
                                      y: view.bounds.size.height - bottomSafeArea - buttonHeight,
                                      width: view.bounds.size.width/4,
                                      height: buttonHeight)
    
    selfieButton.frame = CGRect(x: view.bounds.size.width/2,
                                y: topSafeArea,
                                width: view.bounds.size.width/2,
                                height: buttonHeight)
    
    vauthButton.frame = CGRect(x: 0,
                                 y: view.bounds.size.height - bottomSafeArea - 2 * buttonHeight,
                                 width: view.bounds.size.width/2,
                                 height: buttonHeight)
    
    livenessButton.frame = CGRect(x: view.bounds.size.width/2,
                                  y: view.bounds.size.height - bottomSafeArea - 2 * buttonHeight,
                                  width: view.bounds.size.width/2,
                                  height: buttonHeight)

#if __RFID__ //It appears at the right top corner under the selfieButton
    nfcButton.frame = CGRect(x: view.bounds.size.width/2,
                             y: topSafeArea * 2,
                             width: view.bounds.size.width/2,
                             height: buttonHeight)
#endif
  }
    
  override func viewDidLoad() {
    super.viewDidLoad()
    ocrController.ocrDelegate = self
    
    if #available(iOS 13.0, *) {
      self.view.backgroundColor = .systemBackground
    } else {
      self.view.backgroundColor = .white
    }
    
    view.addSubview(resultTableView)
    setTableViewAnchors()
    resultTableView.delegate = self
    resultTableView.dataSource = self
    
    view.addSubview(cameraButton)
    view.addSubview(vauthButton)
    view.addSubview(livenessButton)
    view.addSubview(galleryButton)
    view.addSubview(photoButton)
    view.addSubview(documentListButton)
    view.addSubview(selfieButton)
#if __RFID__
    view.addSubview(nfcButton)
#endif
    
    cameraButton.addTarget(
        self, action:#selector(showocrViewController), for: .touchUpInside)
    vauthButton.addTarget(
        self, action:#selector(showocrVauthViewController), for: .touchUpInside)
    livenessButton.addTarget(
        self, action:#selector(showocrLivenessViewController), for: .touchUpInside)
    galleryButton.addTarget(
        self, action: #selector(showGalleryImagePickerToProcessImage), for: .touchUpInside)
    photoButton.addTarget(
        self, action: #selector(showPhotoImagePickerToProcessImage), for: .touchUpInside)
    documentListButton.addTarget(
        self, action: #selector(showDocumenttypeList), for: .touchUpInside)
    selfieButton.addTarget(
        self, action: #selector(showSelfiePicker), for: .touchUpInside)
#if __RFID__
    nfcButton.addTarget(
      self, action: #selector(readPassport), for: .touchUpInside)
#endif
    
    setupImagePickerActivityBackground()
    
    self.engineInstance.setInitializationDelegate(self)
    
    DispatchQueue.main.async {
      
      let configPaths = Bundle.main.paths(forResourcesOfType: "ocr", inDirectory: "config")
      
      if configPaths.count == 1 {
        
        self.engineInstance.initializeEngine(configPaths[0])
        // parcing infrormation from config file
        var modesList = [String]() // modes are not sorted
        var docTypesList = [String:[String]]()
        if self.engineInstance.engine != nil {
          let data = Data(self.engineInstance.engine!.description.utf8)
          do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
              // getting list of supported session types and enabling corresponding buttons
              if let names = json["session_types"] as? [String] {
                debugPrint("session_types", names)
                self.sessionTypesStore = names
                if (self.sessionTypesStore.contains("document_recognition")) {
                  self.galleryButton.isEnabled = true
                  self.photoButton.isEnabled = true
                }
                if (self.sessionTypesStore.contains("video_recognition")) {
                  self.cameraButton.isEnabled = true
                }
                if (self.sessionTypesStore.contains("video_authentication")) {
                  self.vauthButton.isEnabled = true
                }
                if (self.sessionTypesStore.contains("liveness_detection")) {
                  self.livenessButton.isEnabled = true
                }
              }
              // getting list of supported document modes and types
              if let targetGroups = json["target_groups"] as? [[String: Any]] {
                for targetGroup in targetGroups {
                  if let targetGroupType = targetGroup["target_group_type"] as? String,
                    let targetMasks = targetGroup["target_masks"] as? [String] {
                    // Use the extracted values as needed
                    if !modesList.contains(targetGroupType) {
                      modesList.append(targetGroupType)
                      docTypesList[targetGroupType] = []
                    }
                    for targetMask in targetMasks {
                      docTypesList[targetGroupType]?.append(targetMask)
                    }
                  }
                }
              }
            }
          } catch let error as NSError {
            print("Failed to load: \(error.localizedDescription)")
          }
        }
        
        if (modesList.count == 1) && (docTypesList[modesList[0]]!.count) == 1 {
          self.setTargetGroupAndMask(
            targetGroup: modesList[0],
            targetMask: docTypesList[modesList[0]]![0])
        }
        
        self.docTypeListViewController = DocTypesListController(docTypesList: docTypesList)
        self.docTypeListViewController.delegateSampSID = self
      
      } else {
        NSLog("No config file at folder")
      }
    }
  }
    
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }
    
   
  func showAlert(msg: String) {
    let alert = UIAlertController(title: "Warning", message: msg, preferredStyle: .alert)
    alert.addAction(UIAlertAction(
        title: NSLocalizedString("OK", comment: "Default action"),
        style: .default,
        handler: { _ in
      NSLog("The \"OK\" alert occured.")
    }))
    self.present(alert, animated: true, completion: nil)
  }
    
  @objc func showGalleryImagePickerToProcessImage() {
    if currentDocumenttypeMask != nil {
        ocrController.sessionParams().setSessionType("document_recognition")
      self.photoLibraryImagePicker.delegate = self
      DispatchQueue.main.async {
        self.pickerIAIContainerBackground.isHidden = true
        self.pickerImageActivityIndicatorContainer.isHidden = true
      }
      
      self.present(self.photoLibraryImagePicker, animated: true, completion: nil)
    } else {
      showAlert(msg: "Select document type")
    }
    self.reinitSelfieButton()
  }
  
  @objc func showPhotoImagePickerToProcessImage() {
    if currentDocumenttypeMask != nil {
        ocrController.sessionParams().setSessionType("document_recognition")
      self.photoCameraImagePicker.delegate = self
      DispatchQueue.main.async {
        self.pickerIAIContainerBackground.isHidden = true
        self.pickerImageActivityIndicatorContainer.isHidden = true
      }
      
      self.present(self.photoCameraImagePicker, animated: true, completion: nil)
    } else {
      showAlert(msg: "Select document type")
    }
    self.reinitSelfieButton()
  }
    
  @objc func showocrViewController() {
    if currentDocumenttypeMask != nil {
      ocrController.sessionParams().setSessionType("video_recognition")
      ocrController.docTypeLabel.isHidden = false
      ocrController.livenessMask.isHidden = true
      ocrController.instructionLabel.isHidden = true
      present(ocrController, animated: true, completion: {
        print("sample: ocrViewController presented")
      })
    } else {
      showAlert(msg: "Select document type")
    }
    self.reinitSelfieButton()
  }
  
  @objc func showocrVauthViewController() {
    if currentDocumenttypeMask != nil {
      ocrController.sessionParams().setSessionType("video_authentication")
      ocrController.docTypeLabel.isHidden = false
      ocrController.livenessMask.isHidden = true
      ocrController.instructionLabel.isHidden = false
      ocrController.instructionLabel.text = "Press shoot button when you are ready"
      present(ocrController, animated: true, completion: {
        print("sample: ocrViewController (Video authentication mode) presented")
      })
    } else {
      showAlert(msg: "Select document type")
    }
    self.reinitSelfieButton()
  }
    
  @objc func showocrLivenessViewController() {
    ocrController.setStartMask()
    ocrController.livenessMask.isHidden = false
    ocrController.sessionParams().setSessionType("liveness_detection")
    ocrController.docTypeLabel.isHidden = true // document type is not needed for liveness session
    ocrController.instructionLabel.isHidden = false
    ocrController.instructionLabel.text = "Press shoot button when you are ready"
    present(ocrController, animated: true, completion: {
      print("sample: ocrViewController (Liveness detection mode) presented")
    })
   self.reinitSelfieButton()
}
  @objc func showDocumenttypeList() {
    present(docTypeListViewController, animated: true, completion: nil)
  }
  
  @objc func showSelfiePicker() {
    if self.currentPhotoImage == nil && engineInstance.session_params?.session_type != "video_authentication"{
      return
    }
    
    self.selfieImagePicker.delegate = self
    self.present(self.selfieImagePicker, animated: true, completion: nil)
  }

#if __RFID__
  //RFID reading - calculating mrzKey
  func calculateMrzKey(mrzDataDict: [String: String]) -> String? {
    guard let number = mrzDataDict["mrz_number"],  let numberCd = mrzDataDict["mrz_cd_number"], let birthDate = mrzDataDict["mrz_birth_date"], let birthDateCd = mrzDataDict["mrz_cd_birth_date"], let expiryDate = mrzDataDict["mrz_expiry_date"], let expiryDateCd = mrzDataDict["mrz_cd_expiry_date"]
    else {
      return nil
    }
    
    let fBirthDate = formatDate(date: birthDate)
    let fExpiryDate = formatDate(date: expiryDate)
    
    let padNumber = pad(number, fieldLength:9)
    let padBirthDate = pad(fBirthDate, fieldLength:6)
    let padExpiryDate = pad(fExpiryDate, fieldLength:6)
    
    return "\(padNumber)\(numberCd)\(padBirthDate)\(birthDateCd)\(padExpiryDate)\(expiryDateCd)"
  }
  
  //RFID reading - Filling with "<"
  func pad( _ value : String, fieldLength:Int ) -> String {
    // Pad out field lengths with < if they are too short
    let paddedValue = (value + String(repeating: "<", count: fieldLength)).prefix(fieldLength)
    return String(paddedValue)
  }

  //RFID reading - Formatting date for mrzKey as "YYMMDD"
  func formatDate(date: String) -> String {
    let dateArray = date.components(separatedBy: ".")
    return "\(dateArray[2].suffix(2))\(dateArray[1])\(dateArray[0])"
  }
  
//RFID reading - reading NFC using PassportReader
  @objc func readPassport() {
    if mrzkey == nil {
      showAlert(msg: "Can not read NFC, no data from document.")
      debugPrint("mrzkey is nil: readPassport is impossible")
      return
    }
    isNFCReaderReady = false
    let passportReader = PassportReader()

    //More information about Data Groups and specifications of reading can be found here: https://www.icao.int/publications/pages/publication.aspx?docnum=9303
    
    //COM: Header and Data Group Presence Information (Mandatory)
    //SOD: Document Security Object (Mandatory)
    //DG1: Machine Readable Zone Information (Mandatory)
    //DG2: Encoded Identification Features - Face (Mandatory)
    
    //    let dataGroups : [DataGroupId] = [.COM, .SOD, .DG1, .DG2, .DG7, .DG11, .DG12, .DG14, .DG15]
    let dataGroups : [DataGroupId] = [.COM, .SOD, .DG1, .DG2]
    Task {
      let customMessageHandler : (NFCViewDisplayMessage)->String? = { (displayMessage) in
        //Other display messages can be customize here
        switch displayMessage {
        case .requestPresentPassport:
          return "Hold your iPhone near an NFC enabled passport."
        default:
          // Return nil for all other messages so we use the provided default
          return nil
        }
      }
      
      do {
        //RFID reading - session of reading NFC
        // @mrzKey - string as <passport number><passport number checksum><date of birth><date of birth checksum><expiry date><expiry date checksum>
        // @tags - array of DataGroups
        // @customDisplayMessage - customized messages while it reading
        let passportModel = try await passportReader.readPassport(mrzKey: mrzkey!, tags: dataGroups, customDisplayMessage:customMessageHandler)
        DispatchQueue.main.async {
          self.passport = passportModel
          self.handlePassport()
          self.isNFCReaderReady = true
        }
      } catch {
        debugPrint("NFC Reading", error.localizedDescription)
        isNFCReaderReady = true
      }
    }
  }
  
  func handlePassport() { //Postpocessing of NFC-reading,
    if passport != nil {
      
      //Check that doctype from recogized document and photo from NFC scanning are exist
      if self.doctyperaw != nil && passport!.passportImage != nil {
        //Creating JSON-structure for ProcessData
        let NFCData: [String: Any] = [
          "doc_type": self.doctyperaw!,
          "physical_fields": [
            "rfid_mrz": [
              "value": passport!.passportMRZ, //MRZ from NFC-scanning
              "type": "String"
            ],
            "rfid_photo": [
              "value": passport!.passportImage!.toJpegString(compressionQuality: 1), //Photo as string from NFC-scanning
              "type": "Image"
            ]
          ]
        ]
        do {
          let jsonString = try JSONSerialization.data(withJSONObject: NFCData, options: [])
          //Creating JSON-string
          let jsonStr = String(data: jsonString, encoding: .utf8)!
          
          //ProcessData returns result with next checks that can be interpreted like this
          let checksDictionary = [
            "fraud_attempt_data": "!Data fraud attempt",
            "fraud_attempt_face": "!Face fraud attempt"
          ]
          
          //Call ProcessData from the same session where the document was recognized
          let r = self.engineInstance.processData(jsonStr)
          for tr_i in 0...r.getRef().targetsCount() - 1 {
            print(r.getRef().target(by: tr_i).description())
            
            let target = r.getRef().target(by: tr_i)
            //Extracting from the result "fraud_attempt" after ProcessData
            
            //Result has new type of items - "fraud_attempt" - checks
            let item_it = target.itemsBegin("fraud_attempt")
            let item_end =  target.itemsEnd("fraud_attempt")
            while !item_it.isEqual(to: item_end) {
              if checksDictionary.keys.contains(item_it.item().name()) {
                self.resultTextFields.append((checksDictionary[item_it.item().name()]!, item_it.item().value()))
              }
              item_it.step()
            }
          }
        } catch {
          print(error)
        }
      }

      //Retrieving data from NFC-scanning to display (hack: using "#" place the fields to the top of resultTextFields)
      self.resultTextFields.append(("#rfid Type", passport!.documentType))
      self.resultTextFields.append(("#rfid Document Number", passport!.documentNumber))
      self.resultTextFields.append(("#rfid First Name", passport!.firstName))
      self.resultTextFields.append(("#rfid Document Expiry Date", passport!.documentExpiryDate))
      self.resultTextFields.append(("#rfid Date Of Birth", passport!.dateOfBirth))
      self.resultTextFields.append(("#rfid Gender", passport!.gender))
      self.resultTextFields.append(("#rfid Issuing Authority", passport!.issuingAuthority))
      self.resultTextFields.append(("#rfid Last Name", passport!.lastName))
      self.resultTextFields.append(("#rfid Nationality", passport!.nationality))
      self.resultTextFields.append(("#rfid Passport MRZ", passport!.passportMRZ))
      self.resultTextFields.append(("#rfid Document Signing Certificate Verified",  passport!.documentSigningCertificateVerified ? "YES" : "NO"))
      self.resultTextFields.append(("#rfid Passport Correctly Signed", passport!.passportCorrectlySigned ? "YES" : "NO"))
      self.resultTextFields.append(("#rfid Passport Data Not Tampered", passport!.passportDataNotTampered ? "YES" : "NO"))
      self.resultTextFields.sort(by: {
          return $0.0 < $1.0
      })
      //Retrieving photo from NFC-scanning to display
      if passport!.passportImage != nil {
        self.resultImageFields.append(("#rfid Photo", passport!.passportImage!))
      }
      self.nfcButton.isEnabled = false
      self.resultTableView.reloadData()
    }
  }
#endif

}

extension UIImage {
  func toJpegString(compressionQuality cq: CGFloat) -> String? {
    if let data = UIImageJPEGRepresentation(self, cq) {
      return data.base64EncodedString(options: .endLineWithLineFeed)
    }
    return nil
  }
}


// MARK: TableView

extension SampleViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return resultTextFields.count + resultImageFields.count + resultTableFields.count
  }
    
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if (indexPath.row < resultTextFields.count) {
      let cell = resultTableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath) as! TextFieldCell
      cell.fieldName.text = resultTextFields[indexPath.row].fieldName
      cell.resultTextView.text = resultTextFields[indexPath.row].value
      return cell
    } else {
      let cell = resultTableView.dequeueReusableCell(withIdentifier: "ImageCell", for: indexPath) as! ImageViewCell
      cell.fieldName.text = resultImageFields[indexPath.row - resultTextFields.count].fieldName
      cell.imageFieldView.image = resultImageFields[indexPath.row - resultTextFields.count].value
      return cell
    } 
  }
    
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableViewAutomaticDimension
  }
}

extension SampleViewController {
    
  func pickImageByUIImage(image: UIImage) {
    self.setupImagePickerActivity()
    self.pickerImageActivityIndicator.startAnimating()
    DispatchQueue.main.async { [weak self] in
      self?.ocrController.processUIImage(image)
      self?.pickerImageActivityIndicator.stopAnimating()
    }
  }
  
  func pickSelfie(image: UIImage) {
    if let photoImage = self.currentPhotoImage {
        let selfieImage = OBJCOCRStudioSDKImage(from: image)
      let similarityResult = self.engineInstance.compareFaces(fromDocument: photoImage.getRef(), andSelfie: selfieImage.getRef())
      
      var status = ""
      var sim = ""
        let target: OBJCOCRStudioSDKTargetRef = similarityResult.getRef().target(by: 0)
      let item_it = target.itemsBegin("string")
      let item_end =  target.itemsEnd("string")
      while !item_it.isEqual(to: item_end) {
        debugPrint((item_it.item().name(), item_it.item().value()))
        if item_it.item().name() == "status" {
          status = item_it.item().value()
        }
        if item_it.item().name() == "similarity_estimation" {
          sim = item_it.item().value()
        }
        item_it.step()
      }
      
      for i in 0..<resultTextFields.count {
        if resultTextFields[i].fieldName == "Selfie check score" {
          resultTextFields.remove(at: i)
          break
        }
      }
      self.resultTextFields.append(("Selfie check score", "\(sim)"))
      self.resultTextFields.sort(by: {
          return $0.0 < $1.0
      })
      self.resultTableView.reloadData()
      self.dismiss(animated: true, completion: nil)
    }
  }
  
  func pickVauthSelfie(image: UIImage) {
    self.setupImagePickerActivity()
    self.pickerImageActivityIndicator.startAnimating()
    DispatchQueue.main.async { [weak self] in
      let r = self?.engineInstance.processSelfie(image)
      self?.pickerImageActivityIndicator.stopAnimating()
      if ((self?.engineInstance) != nil) {
        if self!.engineInstance.sessionEnded {
          if r != nil {
            self!.setResult(result: r!.getRef())
            self!.resultTableView.reloadData()
            self!.reinitSelfieButton()
          }
        }
      }
    }
    self.dismiss(animated: true, completion: nil)
  }
  
  func initImagePickerActivityContainer() -> UIView {
    let activityWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)/5
    let activityContainer = UIView()
    activityContainer.backgroundColor = .black
    activityContainer.alpha = 0.8
    activityContainer.layer.cornerRadius = 10
    
    self.photoLibraryImagePicker.view.addSubview(activityContainer)
    
    activityContainer.translatesAutoresizingMaskIntoConstraints = false
    activityContainer.centerXAnchor.constraint(equalTo: self.photoLibraryImagePicker.view.centerXAnchor).isActive = true
    activityContainer.centerYAnchor.constraint(equalTo: self.photoLibraryImagePicker.view.centerYAnchor).isActive = true
    activityContainer.widthAnchor.constraint(equalToConstant: activityWidth).isActive = true
    activityContainer.heightAnchor.constraint(equalToConstant: activityWidth).isActive = true
    activityContainer.isHidden = true
    
    return activityContainer
  }
  
  func initImagePickerContainerBackground() {
    self.pickerIAIContainerBackground = UIView()
    self.pickerIAIContainerBackground.alpha = 0.2
    self.pickerIAIContainerBackground.backgroundColor = .gray
    self.pickerIAIContainerBackground.isUserInteractionEnabled = false
    self.pickerIAIContainerBackground.isHidden = true
    
    self.photoLibraryImagePicker.view.addSubview(self.pickerIAIContainerBackground)
    
    self.pickerIAIContainerBackground.translatesAutoresizingMaskIntoConstraints = false
    self.pickerIAIContainerBackground.centerXAnchor.constraint(equalTo: self.photoLibraryImagePicker.view.centerXAnchor).isActive = true
    self.pickerIAIContainerBackground.centerYAnchor.constraint(equalTo: self.photoLibraryImagePicker.view.centerYAnchor).isActive = true
    
    self.pickerIAIContainerBackground.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width).isActive = true
    self.pickerIAIContainerBackground.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.height).isActive = true
  }
  
  func addImagePickerActivityToContainer() {
    self.pickerImageActivityIndicator = UIActivityIndicatorView()
    self.pickerImageActivityIndicator.activityIndicatorViewStyle = .whiteLarge
    self.pickerImageActivityIndicator.color = .red
    self.pickerImageActivityIndicatorContainer.addSubview(self.pickerImageActivityIndicator)
    self.pickerImageActivityIndicatorContainer.center  = self.pickerImageActivityIndicator.center
    self.pickerImageActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
    self.pickerImageActivityIndicator.centerXAnchor.constraint(equalTo: self.pickerImageActivityIndicatorContainer.centerXAnchor).isActive = true
    self.pickerImageActivityIndicator.centerYAnchor.constraint(equalTo: self.pickerImageActivityIndicatorContainer.centerYAnchor).isActive = true
  }
  
  func setupImagePickerActivityBackground() {
    initImagePickerContainerBackground()
    self.pickerImageActivityIndicatorContainer = initImagePickerActivityContainer()
    self.addImagePickerActivityToContainer()
  }
  
  func setupImagePickerActivity() {
    self.pickerIAIContainerBackground.isHidden = false
    self.pickerImageActivityIndicatorContainer.isHidden = false
    self.pickerImageActivityIndicator.isHidden = false
  }
    
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    if picker == self.photoLibraryImagePicker || picker == self.photoCameraImagePicker {
      pickImageByUIImage(image: info[UIImagePickerControllerOriginalImage] as! UIImage)
    } else if picker == self.selfieImagePicker {
      if engineInstance.session_params?.session_type == "video_authentication" {
        pickVauthSelfie(image: info[UIImagePickerControllerOriginalImage] as! UIImage)
      } else {
        pickSelfie(image: info[UIImagePickerControllerOriginalImage] as! UIImage)
      }
    }
  }
  
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    self.resultTextView.text = "Recognition cancelled by user!"
    self.resultImageView.image = nil
    self.dismiss(animated: true, completion: nil)
  }
}

extension SampleViewController: OCRStudioSDKViewControllerDelegate {
  func ocrViewControllerDidRecognize(_ result: OBJCOCRStudioSDKResult, from buffer: CMSampleBuffer?) {
    let resultRef = result.getRef()
    if resultRef.allTargetsFinal() {
      self.setResult(result: resultRef)
      resultTableView.reloadData()
      dismiss(animated: true, completion: nil)
    }
  }
  
  func ocrViewControllerDidRecognizeSingleImage(_ result: OBJCOCRStudioSDKResult) {
    self.setResult(result: result.getRef())
    resultTableView.reloadData()
    dismiss(animated: true, completion: nil)
  }
  
  func ocrViewControllerDidCancel() {
    resultTextView.text = "Recognition cancelled by user!"
    resultImageView.image = nil
    dismiss(animated: true, completion: nil)
  }
  
  func ocrViewControllerDidStop(_ result: OBJCOCRStudioSDKResult) {
    self.setResult(result: result.getRef())
    resultTableView.reloadData()
    dismiss(animated: true, completion: nil)
  }
  
  func ocrViewControllerReadyCheckSelfie(_ result: OBJCOCRStudioSDKResult) {
    self.setResult(result: result.getRef(), message: self.engineInstance.currentInstruction)
    resultTableView.reloadData()
    dismiss(animated: true, completion: nil)
    self.selfieButton.isEnabled = true
    self.selfieButton.isHidden = false
  }
}
