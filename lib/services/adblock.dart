/// Simple network-level ad/tracker blocking.
///
/// Domains are matched on exact host OR any parent domain, so
/// `ads.example.com` is blocked when `example.com` is listed.
/// Kept intentionally dependency-free so it can also run inside
/// `shouldInterceptRequest` on every resource request.
class AdBlocker {
  AdBlocker._();

  static const Set<String> _blockedHosts = {
    // Major ad networks & exchanges
    'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
    'googletagservices.com', 'googletagmanager.com', 'google-analytics.com',
    'adservice.google.com', 'adservice.google.co.in', 'pagead2.googlesyndication.com',
    'adnxs.com', 'adsrvr.org', 'adform.net', 'advertising.com',
    'amazon-adsystem.com', 'criteo.com', 'criteo.net', 'taboola.com',
    'outbrain.com', 'pubmatic.com', 'rubiconproject.com', 'openx.net',
    'media.net', 'yieldmo.com', 'teads.tv', 'sharethrough.com',
    'bidswitch.net', 'casalemedia.com', 'contextweb.com', 'indexexchange.com',
    'smartadserver.com', 'sovrn.com', 'lijit.com', 'triplelift.com',
    '33across.com', 'adyoulike.com', 'adcolony.com', 'inmobi.com',
    'unity3d.com', 'vungle.com', 'applovin.com', 'chartboost.com',
    'startapp.io', 'tapjoy.com', 'flurry.com', 'adjust.com',
    'appsflyer.com', 'branch.io', 'kochava.com', 'singular.net',
    'moatads.com', 'doubleverify.com', 'iasds01.com', 'adsafeprotected.com',
    'moat.com', 'scorecardresearch.com', 'quantserve.com', 'imrworldwide.com',
    'hotjar.com', 'mouseflow.com', 'crazyegg.com', 'fullstory.com',
    'newrelic.com', 'nr-data.net', 'bugsnag.com', 'sentry.io',
    // Pop-ups / redirect & scam networks
    'propellerads.com', 'adsterra.com', 'popads.net', 'popcash.net',
    'ad-maven.com', 'hilltopads.net', 'exoclick.com', 'trafficjunky.net',
    'juicyads.com', 'ero-advertising.com', 'eadsrv.com',
    'onclicktraffic.com', 'onclickgenius.com', 'redirection.click',
    'zedo.com', 'adzerk.net', 'revcontent.com', 'mgid.com',
    'yandex.ru', 'analytics.yahoo.com', 'gemius.pl', 'chartbeat.com',
    'admedia.com', 'adk2.com', 'adroll.com', 'bluekai.com',
    'demdex.net', 'exelator.com', 'mathtag.com', 'rlcdn.com',
    'tapad.com', 'cquotient.com', 'bounceexchange.com', 'districtm.io',
    'undertone.com', 'connatix.com', 'vidible.tv', 'spotxchange.com',
    'springserve.com', 'tremorhub.com', 'geomtv.com', 'gumgum.com',
    'zemanta.com', 'stickyadstv.com', 'mercury.wikia.com',
    // Tracking / fingerprinting
    'facebook.net', 'connect.facebook.net', 'ads-twitter.com',
    'analytics.twitter.com', 'bat.bing.com', 'ads.linkedin.com',
    'snap.licdn.com', 'ads.pinterest.com', 'analytics.pinterest.com',
    'ads.tiktok.com', 'analytics.tiktok.com', 'ads.reddit.com',
    'events.redditmedia.com', 'pixel.redditmedia.com', 'track.twitch.tv',
    'countess.twitch.tv', 'gsp1.apple.com', 'metrics.icloud.com',
    'device-metrics-us.amazon.com', 'unagi.amazon.com',
  };

  /// Manual per-site popup allowlist, filled by `allowPopupsForHost`.
  static final Set<String> _popupAllowlist = {};

  /// Returns true when [url] points at a blocked host.
  static bool isBlocked(String? url) {
    if (url == null || url.isEmpty) return false;
    String host;
    try {
      host = Uri.parse(url).host.toLowerCase();
    } catch (_) {
      return false;
    }
    return isHostBlocked(host);
  }

  static bool isHostBlocked(String host) {
    if (host.isEmpty) return false;
    var h = host.toLowerCase();
    while (h.isNotEmpty) {
      if (_blockedHosts.contains(h)) return true;
      final dot = h.indexOf('.');
      if (dot < 0 || dot == h.length - 1) break;
      h = h.substring(dot + 1);
    }
    return false;
  }

  static void allowPopupsForHost(String host) {
    if (host.isNotEmpty) _popupAllowlist.add(host.toLowerCase());
  }

  static bool popupsAllowed(String host) =>
      _popupAllowlist.contains(host.toLowerCase());
}
