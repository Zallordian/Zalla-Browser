import Foundation

/// JavaScript that Zalla injects into pages. Kept as plain strings so the logic stays easy to review.
enum PageScripts {
    /// Asks the page to send only the site name, never the exact page, as the referrer.
    /// A page that sets its own referrer rule can still override this.
    static let referrerTrim = """
    (function () {
      try {
        var meta = document.createElement('meta');
        meta.name = 'referrer';
        meta.content = 'strict-origin';
        (document.head || document.documentElement).appendChild(meta);
      } catch (e) {}
    })();
    """

    /// Modest fingerprinting protection: tiny changes to canvas and audio output, and common values
    /// for processor count and memory. It does not make a browser anonymous.
    static let fingerprintProtection = """
    (function () {
      var seed = (Math.random() * 4294967296) >>> 0;
      function rnd() {
        seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
        return seed / 4294967296;
      }
      function define(target, name, value) {
        try {
          Object.defineProperty(target, name, { get: function () { return value; }, configurable: true });
        } catch (e) {}
      }
      define(Navigator.prototype, 'hardwareConcurrency', 4);
      if ('deviceMemory' in navigator) { define(Navigator.prototype, 'deviceMemory', 8); }

      function perturb(image) {
        var d = image.data;
        var pixels = d.length / 4;
        if (pixels < 16) { return; }
        for (var i = 0; i < 24; i++) {
          var p = Math.floor(rnd() * pixels) * 4;
          var c = Math.floor(rnd() * 3);
          d[p + c] = d[p + c] ^ 1;
        }
      }
      try {
        var originalGetImageData = CanvasRenderingContext2D.prototype.getImageData;
        CanvasRenderingContext2D.prototype.getImageData = function () {
          var image = originalGetImageData.apply(this, arguments);
          try { perturb(image); } catch (e) {}
          return image;
        };
        var noisyCopy = function (canvas) {
          try {
            if (canvas.width < 16 || canvas.height < 16 || canvas.width * canvas.height > 4000000) { return canvas; }
            var copy = document.createElement('canvas');
            copy.width = canvas.width;
            copy.height = canvas.height;
            var context = copy.getContext('2d');
            context.drawImage(canvas, 0, 0);
            var image = originalGetImageData.call(context, 0, 0, copy.width, copy.height);
            perturb(image);
            context.putImageData(image, 0, 0);
            return copy;
          } catch (e) { return canvas; }
        };
        var originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
        HTMLCanvasElement.prototype.toDataURL = function () {
          return originalToDataURL.apply(noisyCopy(this), arguments);
        };
        var originalToBlob = HTMLCanvasElement.prototype.toBlob;
        HTMLCanvasElement.prototype.toBlob = function () {
          return originalToBlob.apply(noisyCopy(this), arguments);
        };
      } catch (e) {}
      try {
        if (window.AudioBuffer) {
          var originalChannel = AudioBuffer.prototype.getChannelData;
          var seen = new WeakSet();
          AudioBuffer.prototype.getChannelData = function () {
            var data = originalChannel.apply(this, arguments);
            try {
              if (!seen.has(data) && data.length > 100) {
                seen.add(data);
                for (var i = 0; i < 12; i++) {
                  var p = Math.floor(rnd() * data.length);
                  data[p] += (rnd() - 0.5) * 1e-7;
                }
              }
            } catch (e) {}
            return data;
          };
        }
        if (window.AnalyserNode) {
          var originalFrequency = AnalyserNode.prototype.getFloatFrequencyData;
          AnalyserNode.prototype.getFloatFrequencyData = function (array) {
            originalFrequency.apply(this, arguments);
            try {
              for (var i = 0; i < array.length; i += 7) { array[i] += (rnd() - 0.5) * 0.1; }
            } catch (e) {}
          };
        }
      } catch (e) {}
    })();
    """

    /// Gives a site the chosen city center instead of a real location.
    static func approximateLocation(latitude: Double, longitude: Double) -> String {
        """
        (function () {
          try {
            var latitude = \(latitude);
            var longitude = \(longitude);
            var position = function () {
              return {
                coords: {
                  latitude: latitude, longitude: longitude, accuracy: 5000,
                  altitude: null, altitudeAccuracy: null, heading: null, speed: null
                },
                timestamp: Date.now()
              };
            };
            var nextWatch = 0;
            var fake = {
              getCurrentPosition: function (success) {
                if (typeof success === 'function') { setTimeout(function () { success(position()); }, 60); }
              },
              watchPosition: function (success) {
                nextWatch += 1;
                if (typeof success === 'function') { setTimeout(function () { success(position()); }, 60); }
                return nextWatch;
              },
              clearWatch: function () {}
            };
            Object.defineProperty(navigator, 'geolocation', { get: function () { return fake; }, configurable: true });
            if (navigator.permissions && navigator.permissions.query) {
              var originalQuery = navigator.permissions.query.bind(navigator.permissions);
              navigator.permissions.query = function (descriptor) {
                if (descriptor && descriptor.name === 'geolocation') {
                  return Promise.resolve({
                    state: 'granted', onchange: null,
                    addEventListener: function () {}, removeEventListener: function () {}
                  });
                }
                return originalQuery(descriptor);
              };
            }
          } catch (e) {}
        })();
        """
    }

    /// Adds the user's CSS for a site as soon as the page starts.
    static func siteCSS(_ css: String) -> String {
        """
        (function () {
          try {
            var css = \(jsString(css));
            var style = document.createElement('style');
            style.setAttribute('data-zalla-site-css', '');
            style.textContent = css;
            (document.head || document.documentElement).appendChild(style);
          } catch (e) {}
        })();
        """
    }

    /// A JavaScript string literal for any text.
    static func jsString(_ text: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [text]),
              let array = String(data: data, encoding: .utf8),
              array.count >= 2 else { return "\"\"" }
        return String(array.dropFirst().dropLast())
    }
}
