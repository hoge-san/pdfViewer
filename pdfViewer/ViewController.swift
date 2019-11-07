//
//  ViewController.swift
//  pdfViewer

import UIKit

class ViewController: UIViewController {
    var pdffile: URL?

    @IBOutlet weak var urlTextField: UITextField!


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    @IBAction func actionPDFView(_ sender: Any) {
        guard let url = urlTextField.text  else { return }

        let pdf = isPdf(url: URL(string: url)!)
        if pdf {
            print("URL: " + url)
            self.pdffile = URL(string: url)
        } else {
            print("not PDF")
            self.pdffile = nil
        }

    }
    @IBAction func actionPDF1(_ sender: Any) {
        let url = "https://jp.sharp/support/aquos/doc/lc20f5_mn_exp.pdf"
        let pdf = isPdf(url: URL(string: url)!)
        if pdf {
            self.pdffile = URL(string: url)
        }
    }


    private func isPdf(url: URL) -> (Bool) {
        var result: Bool = false
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        print("head")
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { (data, urlResponse, error) in
            guard let urlResponse = urlResponse as? HTTPURLResponse else {
                // レスポンスが得られなかった場合
                result = false
                semaphore.signal()
                return
            }
            if let contentType = urlResponse.allHeaderFields["Content-Type"] as? String {
                if contentType.contains("application/pdf") {
                    result = true
                    semaphore.signal()
                    return
                }
            }
            if let contentDisposition = urlResponse.allHeaderFields["Content-Disposition"] as? String {
                if contentDisposition.contains(".pdf") {
                    result = true
                    semaphore.signal()
                    return
                }
            }
            result = false
            semaphore.signal()
        }.resume()
        semaphore.wait()
        print("return Result: " + String(result))
        return result
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if segue.identifier == "toPDFViewController",
            let choiceVC = segue.destination as? PDFViewController {
            choiceVC.remotePDFFile = self.pdffile
        }
    }

}
