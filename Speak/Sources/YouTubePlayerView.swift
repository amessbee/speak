import SwiftUI
import WebKit

struct YouTubePlayerView: NSViewRepresentable {
    let urlString: String
    var restartToken: UUID
    var onKeyDown: ((_ keyCode: Int, _ meta: Bool) -> Void)? = nil
    var onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onKeyDown: onKeyDown, onFinished: onFinished)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "videoFinished")
        config.userContentController.add(context.coordinator, name: "keyNav")
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15"
        view.setValue(false, forKey: "drawsBackground")
        view.uiDelegate = context.coordinator
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view

        if let videoID = Self.extractVideoID(from: urlString) {
            view.loadHTMLString(Self.makeHTML(videoID: videoID),
                                baseURL: URL(string: "https://www.youtube-nocookie.com"))
        }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.onKeyDown  = onKeyDown
        context.coordinator.onFinished = onFinished
        guard context.coordinator.lastRestartToken != restartToken else { return }
        context.coordinator.lastRestartToken = restartToken
        nsView.evaluateJavaScript("""
            var f = document.getElementById('ytplayer');
            if (f && f.contentWindow) {
                f.contentWindow.postMessage(
                    JSON.stringify({event:'command',func:'seekTo',args:[0,true]}), '*');
                f.contentWindow.postMessage(
                    JSON.stringify({event:'command',func:'playVideo',args:[]}), '*');
            }
        """, completionHandler: nil)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        var onKeyDown: ((_ keyCode: Int, _ meta: Bool) -> Void)?
        var onFinished: () -> Void
        var lastRestartToken: UUID = UUID()
        weak var webView: WKWebView?

        init(onKeyDown: ((_ keyCode: Int, _ meta: Bool) -> Void)?, onFinished: @escaping () -> Void) {
            self.onKeyDown  = onKeyDown
            self.onFinished = onFinished
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            DispatchQueue.main.async {
                switch message.name {
                case "videoFinished":
                    self.onFinished()
                case "keyNav":
                    guard let body = message.body as? [String: Any],
                          let keyCode = body["keyCode"] as? Int else { return }
                    let meta = body["metaKey"] as? Bool ?? false
                    self.onKeyDown?(keyCode, meta)
                default:
                    break
                }
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            completionHandler()
        }
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            completionHandler(true)
        }
    }

    // MARK: - HTML wrapper
    //
    // Architecture: a hidden 1×1 focus-trap div (#kt) lives in our main frame, where
    // window.webkit.messageHandlers is guaranteed to be available. All key handling
    // runs there — no iframe injection needed. Whenever the YouTube iframe steals focus
    // (user clicks on it), the blur listener on #kt steals it back after 100 ms, which
    // is long enough for the click action to register but short enough to be invisible.
    //
    // Video-end detection listens for YouTube's postMessage state-change events; both
    // the modern "infoDelivery" format and the classic "onStateChange" format are handled.

    private static func makeHTML(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            html,body{margin:0;padding:0;width:100%;height:100%;background:#000;overflow:hidden}
            iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0}
            #kt{position:fixed;top:-2px;left:-2px;width:1px;height:1px;opacity:0;outline:none}
          </style>
        </head>
        <body>
          <div id="kt" tabindex="0"></div>
          <iframe id="ytplayer"
            src="https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=1&controls=1&rel=0&modestbranding=1&enablejsapi=1"
            allow="autoplay; fullscreen; encrypted-media; picture-in-picture"
            allowfullscreen>
          </iframe>
          <script>
          (function(){
            var HANDLED=[27,32,37,38,39,40,72,80,90];
            var kt=document.getElementById('kt');
            var iframe=document.getElementById('ytplayer');

            function grab(){kt.focus();}

            // Restore focus whenever the iframe steals it
            kt.addEventListener('blur',function(){setTimeout(grab,100);});
            iframe.addEventListener('focus',function(){setTimeout(grab,100);});

            // Initial grab: wait for the iframe to finish its own focus dance on load
            window.addEventListener('load',function(){setTimeout(grab,300);});
            setTimeout(grab,1000);

            kt.addEventListener('keydown',function(e){
              if(HANDLED.indexOf(e.keyCode)<0)return;
              e.preventDefault();
              e.stopPropagation();
              window.webkit.messageHandlers.keyNav.postMessage(
                {keyCode:e.keyCode,metaKey:e.metaKey||false});
            });

            // Video-end detection via YouTube's enablejsapi postMessage protocol
            window.addEventListener('message',function(e){
              var d;
              try{d=JSON.parse(e.data);}catch(_){return;}
              var ended=
                (d.event==='onStateChange'&&d.info===0)||
                (d.event==='infoDelivery'&&d.info&&d.info.playerState===0);
              if(ended){
                try{window.webkit.messageHandlers.videoFinished.postMessage('ended');}catch(_){}
              }
            });
          })();
          </script>
        </body>
        </html>
        """
    }

    // MARK: - Video ID extraction

    static func extractVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if url.host?.hasSuffix("youtu.be") == true {
            let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return id.isEmpty ? nil : id
        }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = components.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty {
            return v
        }
        let parts = url.pathComponents
        if parts.count >= 3, (parts[1] == "embed" || parts[1] == "shorts") { return parts[2] }
        return nil
    }
}
