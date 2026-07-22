//
//  RedirectBlockingDelegate.swift
//  LimesTV
//
//  Stops URLSession from auto-following redirects. The EPG shortener redirects
//  from HTTPS to a plain-HTTP host; App Transport Security blocks that downgrade
//  mid-redirect even with arbitrary loads allowed, so we capture the redirect
//  target and request it directly as a top-level HTTP load instead.
//

import Foundation

final class RedirectBlockingDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Returning nil delivers the redirect response itself to the caller,
        // instead of following it, so we can read its Location header.
        completionHandler(nil)
    }
}
