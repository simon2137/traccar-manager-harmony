import { describe, it, expect } from '@ohos/hypium';
import {
  buildUri,
  composeServerUrlFromDeepLink,
  isDownloadable,
  isOAuthAuthorizeRequest,
  isServerRootOrLogin,
  isValidServerUrl,
  lastPathSegment,
  normalizeServerUrl,
  originOf,
  parseUri,
  pathOf,
  QueryParam,
  rewriteRedirectToAppScheme,
  UriParts
} from '../main/ets/common/model/UriModel';
import { TraccarConstants } from '../main/ets/common/constants/TraccarConstants';

/**
 * 移植正确性的回归护栏。
 *
 * 上游这些判断散落在 lib/main_screen.dart 的 shouldOverrideUrlLoading / _launchAuthorizeRequest /
 * uriLinkStream / PopScope 里，移植后全部收敛到 UriModel 这层纯函数。这里的每一条断言都对应
 * 上游的一处行为分支，改 UriModel 时先把上游行为读一遍再改断言。
 */
export default function uriModelTest() {
  describe('uriModelTest', () => {

    it('parsesUrlWithPathQueryFragment', 0, () => {
      const parts: UriParts = parseUri('https://demo.traccar.org/login?x=1#frag');
      expect(parts.scheme).assertEqual('https');
      expect(parts.authority).assertEqual('demo.traccar.org');
      expect(parts.path).assertEqual('/login');
      expect(parts.query).assertEqual('x=1');
      expect(parts.fragment).assertEqual('frag');
    });

    it('parsesUrlWithoutPath', 0, () => {
      const parts: UriParts = parseUri('https://demo.traccar.org');
      expect(parts.authority).assertEqual('demo.traccar.org');
      expect(parts.path).assertEqual('');
      expect(parts.pathSegments().length).assertEqual(0);
    });

    it('parsesDeepLinkHostAsAuthority', 0, () => {
      // 深链的 host 位置承载着上游 OAuth 回调路径的第一段，必须按 authority 解析。
      const parts: UriParts = parseUri('org.traccar.manager://callback/auth?code=abc&state=s');
      expect(parts.scheme).assertEqual('org.traccar.manager');
      expect(parts.authority).assertEqual('callback');
      expect(parts.path).assertEqual('/auth');
      expect(parts.queryValue('code')).assertEqual('abc');
      expect(parts.queryParams().length).assertEqual(2);
    });

    it('parsesOpaqueScheme', 0, () => {
      const parts: UriParts = parseUri('mailto:someone@example.com');
      expect(parts.scheme).assertEqual('mailto');
      expect(parts.authority).assertEqual('');
      expect(parts.path).assertEqual('someone@example.com');
    });

    it('splitsHostAndPort', 0, () => {
      const parts: UriParts = parseUri('http://192.168.1.5:8082/api');
      expect(parts.host()).assertEqual('192.168.1.5');
      expect(parts.port()).assertEqual('8082');
      expect(parts.path).assertEqual('/api');
    });

    it('normalizesAndValidatesServerUrl', 0, () => {
      expect(normalizeServerUrl('  https://demo.traccar.org//  ')).assertEqual('https://demo.traccar.org');
      expect(isValidServerUrl('https://demo.traccar.org')).assertTrue();
      expect(isValidServerUrl('http://192.168.1.5:8082')).assertTrue();
      // 少了 scheme、scheme 不对、带空格、空串 —— 对应上游 ErrorScreen 的 "Invalid URL"。
      expect(isValidServerUrl('demo.traccar.org')).assertFalse();
      expect(isValidServerUrl('ftp://demo.traccar.org')).assertFalse();
      expect(isValidServerUrl('https://ho st')).assertFalse();
      expect(isValidServerUrl('   ')).assertFalse();
    });

    it('extractsOriginAndPath', 0, () => {
      expect(originOf('https://demo.traccar.org/login?x=1')).assertEqual('https://demo.traccar.org');
      expect(pathOf('https://demo.traccar.org/login?x=1')).assertEqual('/login');
      expect(lastPathSegment('https://demo.traccar.org/api/reports/report.xlsx')).assertEqual('report.xlsx');
      expect(lastPathSegment('https://demo.traccar.org')).assertEqual('');
    });

    it('detectsDownloadableAttachments', 0, () => {
      const extensions: string[] = TraccarConstants.DOWNLOADABLE_EXTENSIONS;
      expect(isDownloadable('https://demo.traccar.org/api/report.xlsx', extensions)).assertTrue();
      expect(isDownloadable('https://demo.traccar.org/api/REPORT.XLSX', extensions)).assertTrue();
      expect(isDownloadable('https://demo.traccar.org/api/track.kml?deviceId=1', extensions)).assertTrue();
      expect(isDownloadable('https://demo.traccar.org/api/route.gpx', extensions)).assertTrue();
      expect(isDownloadable('https://demo.traccar.org/api/export.csv', extensions)).assertTrue();
      // 上游只看路径最后一段的后缀：不是白名单 / 只有点 / 无路径 都不下载。
      expect(isDownloadable('https://demo.traccar.org/api/report.pdf', extensions)).assertFalse();
      expect(isDownloadable('https://demo.traccar.org/api/report.', extensions)).assertFalse();
      expect(isDownloadable('https://demo.traccar.org/', extensions)).assertFalse();
    });

    it('rewritesOAuthRedirectToAppScheme', 0, () => {
      // 上游 _launchAuthorizeRequest：丢掉原 redirect_uri 的 host，把**第一段路径**当作深链的 host，
      // 其余路径与 query 原样搬运。这样 OAuth 回跳时 composeServerUrlFromDeepLink 才能把路径
      // 原样拼回服务器地址（回跳路径是服务器相对路径，原 host 本来就该丢弃）。
      expect(rewriteRedirectToAppScheme('https://app.example.com/cb/auth?state=1', 'org.traccar.manager'))
        .assertEqual('org.traccar.manager://cb/auth?state=1');
      expect(rewriteRedirectToAppScheme('https://app.example.com/cb', 'org.traccar.manager'))
        .assertEqual('org.traccar.manager://cb');
      // 没有路径段时原样返回：此时没有任何段可以承载 host，改写只会得到一个空 host 的废链。
      expect(rewriteRedirectToAppScheme('https://app.example.com', 'org.traccar.manager'))
        .assertEqual('https://app.example.com');
      // 闭环护栏：改写出去再拼回来，服务器相对路径必须一字不差。
      const deepLink: string =
        rewriteRedirectToAppScheme('https://app.example.com/cb/auth?state=1', 'org.traccar.manager');
      expect(composeServerUrlFromDeepLink('https://demo.traccar.org', deepLink))
        .assertEqual('https://demo.traccar.org/cb/auth?state=1');
    });

    it('rebuildsServerUrlFromDeepLink', 0, () => {
      // 上游 uriLinkStream：host + 各路径段拼回服务器 URL。
      expect(composeServerUrlFromDeepLink('https://demo.traccar.org/', 'org.traccar.manager://login'))
        .assertEqual('https://demo.traccar.org/login');
      // 带 code 时额外补 redirect_uri（值为不带 query 的深链本身），供 Web 端校验。
      const composed: string =
        composeServerUrlFromDeepLink('https://demo.traccar.org', 'org.traccar.manager://callback/auth?code=abc');
      expect(composed).assertContain('https://demo.traccar.org/callback/auth?code=abc');
      expect(composed).assertContain('redirect_uri=');
    });

    it('detectsOAuthAuthorizeRequest', 0, () => {
      const required: string[] = TraccarConstants.OAUTH_PARAMS;
      expect(isOAuthAuthorizeRequest(
        'https://s/oauth/authorize?response_type=code&client_id=c&redirect_uri=r&scope=s', required)).assertTrue();
      // 少一个参数就不该被劫持到外部浏览器。
      expect(isOAuthAuthorizeRequest(
        'https://s/oauth/authorize?response_type=code&client_id=c&redirect_uri=r', required)).assertFalse();
      expect(isOAuthAuthorizeRequest('https://s/login', required)).assertFalse();
    });

    it('detectsServerRootOrLogin', 0, () => {
      const server: string = 'https://demo.traccar.org';
      // 这两个位置返回键应当退出应用（上游 PopScope 的判定）。
      expect(isServerRootOrLogin('https://demo.traccar.org/', server)).assertTrue();
      expect(isServerRootOrLogin('https://demo.traccar.org', server)).assertTrue();
      expect(isServerRootOrLogin('https://demo.traccar.org/login', server)).assertTrue();
      expect(isServerRootOrLogin('https://demo.traccar.org/login/', server)).assertTrue();
      // 更深的位置、别的站点都应当继续后退。
      expect(isServerRootOrLogin('https://demo.traccar.org/settings', server)).assertFalse();
      expect(isServerRootOrLogin('https://other.example.com/', server)).assertFalse();
    });

    it('buildsUriWithEncoding', 0, () => {
      const params: QueryParam[] = [new QueryParam('q', 'a b&c')];
      expect(buildUri('https', 'demo.traccar.org', '/api', params))
        .assertEqual('https://demo.traccar.org/api?q=a%20b%26c');
    });
  });
}
