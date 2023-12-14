//
//  ViewController.swift
//  SampleGemini
//
//  Created by sakiyamaK on 2023/12/14.
//

import UIKit
import DeclarativeUIKit
import ObservableUIKit
import GoogleGenerativeAI
import Kingfisher

@Observable
class ViewModel {
    private(set) var text: String
    private(set) var loading: Bool = false
    private(set) var error: Error?

    /**
     自身で生成したAPIKeyをいれてね
     */
    private let textModel = GenerativeModel(
        name: "gemini-pro",
        apiKey:
            "ここに[https://makersuite.google.com/app/apikey]で生成したAPIKeyを入れてください"
    )
    
    private let textImageModel = GenerativeModel(
        name: "gemini-pro-vision",
        apiKey:
            "ここに[https://makersuite.google.com/app/apikey]で生成したAPIKeyを入れてください"
    )

    
    init(text: String = "") {
        self.text = text
    }
    
    func generateContentStream(text: String, image: UIImage? = nil) async {
        do {
            self.text = ""
            loading = true
            let responseStream: AsyncThrowingStream<GenerateContentResponse, Error>
            if let image {
                responseStream = textImageModel.generateContentStream(text, image)
            } else {
                responseStream = textModel.generateContentStream(text)
            }
            for try await cunk in responseStream {
                self.text += cunk.text ?? ""
            }
        }
        catch let e {
            loading = false
            error = e
            print(e)
        }
    }
    
    func generateContent(text: String, image: UIImage? = nil) async {
        do {
            self.text = ""
            loading = true
            let response: GenerateContentResponse
            if let image {
                response = try await textImageModel.generateContent(text, image)
            } else {
                response = try await textModel.generateContent(text)
            }
            loading = false
            self.text = response.text ?? ""
        }
        catch let e {
            loading = false
            error = e
            print(e)
        }
    }
}

final class SampleGeminiViewController: UIViewController {
    
    private let viewMModel = ViewModel()
    
    private var searchTextField: UITextField!
    private var imageView: UIImageView!
    private var imageSearchTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        applyView {
            $0.backgroundColor(.white)
        }.applyNavigationItem({[weak self] in
            guard let self else { return }
            $0.rightBarButtonItem = UIBarButtonItem(title: "教えてGeminiさん！")
                .action(self, {[weak self] _ in
                    guard let self, let prompt = self.searchTextField.text else { return }
                    Task {
                        if let image = self.imageView.image {
                            await self.viewMModel.generateContent(text: prompt, image: image)
                        } else {
                            await self.viewMModel.generateContent(text: prompt)
                        }
                    }
                })
        }).declarative {
            UIStackView.vertical {
                UITextField(assign: &searchTextField)
                    .delegate(self)
                    .padding()
                    .border(color: .gray, width: 1)
                    .customSpacing(16)
                
                UITextField(assign: &imageSearchTextField)
                    .delegate(self)
                    .padding()
                    .border(color: .gray, width: 1)
                    .customSpacing(16)
                
                UIImageView(assign: &imageView)
                    .contentMode(.scaleAspectFit)
                    .backgroundColor(.lightGray)
                    .size(width: 200, height: 200)
                    .centerX()
                    .customSpacing(16)
                
                UITextView()
                    .isEditable(false)
                    .contentInset(.init(all: 8))
                    .apply {
                        $0.observation(keyPath: \.text) {[weak self] in
                            self?.viewMModel.text
                        }
                    }
            }
            .padding()
        }
        .declarative {
            UIActivityIndicatorView()
                .apply {
                    $0.observation(keyPath: \.loading) {[weak self] in
                        self?.viewMModel.loading ?? false
                    }
                }
        }

        observation(keyPath: \.error) {
            self.viewMModel.error
        }
    }
}

extension SampleGeminiViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if imageSearchTextField == textField,
           let text = textField.text,
           let url = URL(string: text) {
            imageView.kf.setImage(with: url)
        }
        return true
    }
}

private extension UIViewController {
    var error: Error? {
        get {
            nil
        }
        set {
            guard let newValue else { return }
            let vc = UIAlertController(title: "APIエラー", message: newValue.localizedDescription, preferredStyle: .alert) {
                UIAlertAction(title: "閉じる",
                                 style: .default,
                                 handler: nil)
            }
            present(vc, animated: true, completion: nil)
        }
    }
}

private extension UIActivityIndicatorView {
    var loading: Bool {
        get {
            self.isAnimating
        }
        set {
            if newValue {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }
}
