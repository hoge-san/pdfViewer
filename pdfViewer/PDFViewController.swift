//
//  PDFViewController.swift

import UIKit
import PDFKit

class PDFViewController: UIViewController, UISearchBarDelegate  {
    @IBOutlet weak var pdfViewArea: UIView!
    @IBOutlet weak var searchView: UIView!
    @IBOutlet weak var searchBar: UISearchBar!

    var pdfView: PDFView!
    var alertController: UIAlertController?
    var progressView: UIProgressView!

    var remotePDFFile: URL!

    var pdfDocument: PDFDocument?

    var searchedItems: [PDFSelection]?
    var selectedItem: Int = 0

    var totalPage: Int = 0

    // MARK: - ViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        self.searchView.isHidden = true
        self.searchBar.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if remotePDFFile == nil { return }
        let pview: PDFView? = PDFView(frame: self.pdfViewArea.frame)
        if  pview == nil { return }
        self.pdfView = pview
        self.view.addSubview(self.pdfView)

        showPDFFile(url: self.remotePDFFile)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.PDFViewPageChanged, object: nil)
    }

    // MARK: - Actions
    @IBAction func searchAction(_ sender: Any) {
        if self.searchView.isHidden {
            self.showSearchBar()
        } else {
            self.hideSearchBar()
        }
    }

    private func hideSearchBar() {
        self.searchView.isHidden = true
    }

    private func showSearchBar() {
        self.searchView.isHidden = false
        self.view.bringSubviewToFront(self.searchView)
    }

    private func gotoSelectedItemPage() {
        if let item = self.searchedItems?[self.selectedItem] {
            DispatchQueue.main.async {
                self.pdfView.go(to: item)
            }
        }
    }

    @IBAction func backwordAction(_ sender: Any) {
        if self.selectedItem > 0 {
            self.selectedItem -= 1
        }
        self.gotoSelectedItemPage()
    }
    
    @IBAction func forwardAction(_ sender: Any) {
        if self.selectedItem < self.searchedItems!.count - 1 {
            self.selectedItem += 1
        }
        self.gotoSelectedItemPage()
    }


    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar.endEditing(true)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if let text = searchBar.text {
            if text.isEmpty {
                self.hideSearchBar()
            } else {
                DispatchQueue.main.async {
                    self.findItems(text: text)
                }
            }
        }
    }
    
    // MARK: - file cache

    // URLごとにCacheフォルダにファイルを作る。
    // ファイル名は、/を_に変更してファイル名にする
    private func url2CachePath(url: URL) -> (String) {
        let result = "pdf_" + url.absoluteString.replacingOccurrences(of: "/", with: "_")
        return result
    }

    private func getPDFPath(url: URL) -> (URL) {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let path = url2CachePath(url: url)

        let destinationURL = cacheDirectory.appendingPathComponent(path)
        return destinationURL
    }

    private func getPDFFromCache(url: URL) -> (URL?) {
        let destinationURL = getPDFPath(url: url)
        if FileManager.default.fileExists(atPath: destinationURL.relativePath) {
            print("file exists: " + destinationURL.absoluteString)
            return destinationURL
        }
        print("file not exists: " + destinationURL.absoluteString)
        return nil
    }

    private func movePDFToCache(from: URL, url: URL) {
        do {
            try FileManager.default.copyItem(at: from, to: getPDFPath(url: url))
        } catch {
            print("error")
        }
    }

    // MARK: - download or retrive cache
    // 存在すれば、ローカルキャッシュを表示
    // 存在しなければ、リモートファイルを取得
    func showPDFFile(url: URL) {
        let filePath = self.getPDFFromCache(url: url)
        if let mPath = filePath {
            print("===== cached document")
            self.showPDF(url: mPath)
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        let urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        let downloadTask = urlSession.downloadTask(with: request)

        self.showAlert()
        downloadTask.resume()
    }

    // MARK: - PDFViewer

    //PDFを表示
    func showPDF(url: URL) {
        self.pdfView.autoScales = true
        self.pdfView.displayMode = .singlePageContinuous
        self.pdfView.displayDirection = .horizontal
        self.pdfView.displaysPageBreaks = true

        let document = PDFDocument(url: url)
        self.pdfView.document = document
        self.pdfDocument  = document
        self.pdfView.autoScales = true

        self.totalPage = document?.pageCount ?? 0

        self.setPageNumber()
        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChange(notification:)), name: Notification.Name.PDFViewPageChanged, object: nil)
    }

    private func setPageNumber() {
        if let page = self.pdfView.currentPage?.pageRef?.pageNumber {
            self.title = String(page) + " / " + String(self.totalPage)
        }
    }

    @objc private func handlePageChange(notification: Notification)
    {
        // Do your stuff here like hiding PDFThumbnailView...
        self.setPageNumber()
    }

    func findItems(text: String) {
        self.searchedItems = self.pdfView.document?.findString(text, withOptions: .caseInsensitive)

        self.searchedItems?.forEach { selection in
            selection.color = .yellow
        }

        pdfView.highlightedSelections = self.searchedItems

        // self.pdfView.setCurrentSelection(self.searchedItems?.first, animate: true)
        self.pdfView.go(to: (self.searchedItems?.first)!)
    }

    func showAlert() {
        let title = "読み込み中"
        let message = ""
        self.alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        self.alertController?.view.bounds.size.width = 300
        self.alertController?.view.bounds.size.height = 200

        self.progressView = UIProgressView()
        self.progressView.progressViewStyle = .default
        self.progressView.progress = 0.0
        self.progressView.autoresizesSubviews = true

        self.alertController?.view.addSubview(self.progressView)

        // autolayout 関係
        self.progressView.frame.size.height = 5
        self.progressView.translatesAutoresizingMaskIntoConstraints = false
        self.progressView.leadingAnchor.constraint(equalTo: (self.alertController?.view.leadingAnchor)! , constant: 20.0).isActive = true
        self.progressView.trailingAnchor.constraint(equalTo: (self.alertController?.view.trailingAnchor)! , constant: -20.0).isActive = true
        self.progressView.bottomAnchor.constraint(equalTo: (self.alertController?.view.bottomAnchor)! , constant: -20.0).isActive = true

        present(self.alertController!, animated: true, completion: nil)
    }

    func hideAlert() {
        self.alertController?.dismiss(animated: true, completion: {
            self.alertController = nil
        })
    }
}

// MARK: - URLSessionDownloadDelegate
extension PDFViewController: URLSessionDownloadDelegate {
    // ファイルダウンロード後処理
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("downloadLocation:", location)
        DispatchQueue.main.async {
            self.hideAlert()
        }

        guard let url = downloadTask.originalRequest?.url else { return }
        self.movePDFToCache(from: location, url: url)

        DispatchQueue.main.async {
            // ファイルダウンロード後PDF表示
            self.showPDF(url: self.getPDFPath(url: url))
        }
    }

    // プログレスバー表示用
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        var calculatedProgress: Float
        if totalBytesExpectedToWrite > 0 {
            calculatedProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        } else {
            // 全バイト数がわからない時。プログレスバーを進める
            // Float(10000000)は、ファイルサイズを10MBとしてプログラスバーを表示
            calculatedProgress = Float(totalBytesWritten) / Float(10000000)
        }

        DispatchQueue.main.async {
            self.progressView.setProgress(calculatedProgress, animated: true)
        }
    }
}
