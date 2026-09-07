import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/utils/legal_links.dart';

/// The legal URLs are derived from the API base rather than configured
/// separately, so they follow the backend across environments. That derivation
/// is the only logic here, and getting it wrong means a 404 on the privacy
/// policy -- the one link a Play reviewer is guaranteed to click.
void main() {
  group('siteRootFrom', () {
    test('strips the /api mount', () {
      expect(
        LegalLinks.siteRootFrom('https://api.example.com/api'),
        'https://api.example.com',
      );
    });

    test('strips a trailing slash as well as /api', () {
      expect(
        LegalLinks.siteRootFrom('https://api.example.com/api/'),
        'https://api.example.com',
      );
    });

    test('leaves a base that has no /api suffix alone', () {
      expect(
        LegalLinks.siteRootFrom('https://api.example.com'),
        'https://api.example.com',
      );
    });

    test('handles the local development shape, port and all', () {
      expect(
        LegalLinks.siteRootFrom('http://192.168.1.9:8000/api'),
        'http://192.168.1.9:8000',
      );
    });

    test('does not eat a host that merely ends in the letters api', () {
      // "socialapi.example.com" must not lose four characters.
      expect(
        LegalLinks.siteRootFrom('https://socialapi.example.com'),
        'https://socialapi.example.com',
      );
    });

    test('tolerates surrounding whitespace', () {
      expect(
        LegalLinks.siteRootFrom('  https://api.example.com/api  '),
        'https://api.example.com',
      );
    });
  });

  group('page URLs', () {
    test('every page hangs off the derived root with a trailing slash', () {
      // Django's APPEND_SLASH would redirect without the trailing slash, and a
      // redirect on the URL submitted to Play is worth avoiding.
      for (final url in [
        LegalLinks.privacy,
        LegalLinks.terms,
        LegalLinks.dataDeletion,
      ]) {
        expect(url.startsWith(LegalLinks.siteRoot), isTrue, reason: url);
        expect(url.endsWith('/'), isTrue, reason: url);
        expect(url.contains('//privacy'), isFalse, reason: url);
      }
    });

    test('the three pages are distinct', () {
      final urls = {
        LegalLinks.privacy,
        LegalLinks.terms,
        LegalLinks.dataDeletion,
      };
      expect(urls.length, 3);
    });
  });
}
