/**
 * URI 解析/拼接的纯函数层。
 *
 * 上游用 Dart 的 `Uri` 类（lib/main_screen.dart:55、:213-260），鸿蒙没有等价物，
 * 这里用零依赖的纯函数重建所需子集。刻意不引入任何 @kit 依赖，以便在无设备环境
 * 下用 hypium 单测覆盖（见 entry/src/test/UriModel.test.ets）。
 */

/** 查询参数键值对。保序，允许重名（OAuth 回调里 state/code 可能重复）。 */
export class QueryParam {
  name: string = '';
  value: string = '';

  constructor(name: string, value: string) {
    this.name = name;
    this.value = value;
  }
}

/** 解析后的 URI。字段名与 Dart Uri 对齐但只保留本工程用到的部分。 */
export class UriParts {
  scheme: string = '';
  authority: string = '';
  path: string = '';
  query: string = '';
  fragment: string = '';

  /** 去掉 userinfo 后的主机名（不含端口）。 */
  host(): string {
    let value: string = this.authority;
    const at: number = value.lastIndexOf('@');
    if (at >= 0) {
      value = value.substring(at + 1);
    }
    // IPv6 字面量 [::1]:8080
    if (value.startsWith('[')) {
      const close: number = value.indexOf(']');
      return close >= 0 ? value.substring(0, close + 1) : value;
    }
    const colon: number = value.lastIndexOf(':');
    return colon >= 0 ? value.substring(0, colon) : value;
  }

  /** 端口串；未显式给出时返回空串。 */
  port(): string {
    let value: string = this.authority;
    const at: number = value.lastIndexOf('@');
    if (at >= 0) {
      value = value.substring(at + 1);
    }
    if (value.startsWith('[')) {
      const close: number = value.indexOf(']');
      if (close >= 0 && close + 1 < value.length && value.charAt(close + 1) === ':') {
        return value.substring(close + 2);
      }
      return '';
    }
    const colon: number = value.lastIndexOf(':');
    return colon >= 0 ? value.substring(colon + 1) : '';
  }

  /** 路径分段，已做百分号解码，忽略空段（与 Dart pathSegments 一致）。 */
  pathSegments(): string[] {
    const result: string[] = [];
    const parts: string[] = this.path.split('/');
    for (const part of parts) {
      if (part.length > 0) {
        result.push(decodeComponent(part));
      }
    }
    return result;
  }

  queryParams(): QueryParam[] {
    return parseQuery(this.query);
  }

  /** 取第一个同名参数的值；不存在返回空串。 */
  queryValue(name: string): string {
    const params: QueryParam[] = this.queryParams();
    for (const param of params) {
      if (param.name === name) {
        return param.value;
      }
    }
    return '';
  }

  hasParams(names: string[]): boolean {
    const params: QueryParam[] = this.queryParams();
    for (const name of names) {
      let found: boolean = false;
      for (const param of params) {
        if (param.name === name) {
          found = true;
          break;
        }
      }
      if (!found) {
        return false;
      }
    }
    return true;
  }

  /** `scheme://authority`，用于与服务器 authority 比较。无 authority 时退回 scheme。 */
  origin(): string {
    if (this.authority.length === 0) {
      return this.scheme;
    }
    return `${this.scheme}://${this.authority}`;
  }
}

/** 百分号解码；输入非法时原样返回，绝不抛异常。 */
export function decodeComponent(raw: string): string {
  try {
    return decodeURIComponent(raw);
  } catch (err) {
    return raw;
  }
}

/** 百分号编码（查询参数值用）。 */
export function encodeComponent(raw: string): string {
  try {
    return encodeURIComponent(raw);
  } catch (err) {
    return raw;
  }
}

function parseQuery(query: string): QueryParam[] {
  const result: QueryParam[] = [];
  if (query.length === 0) {
    return result;
  }
  const pieces: string[] = query.split('&');
  for (const piece of pieces) {
    if (piece.length === 0) {
      continue;
    }
    const eq: number = piece.indexOf('=');
    if (eq < 0) {
      result.push(new QueryParam(decodeComponent(piece), ''));
    } else {
      result.push(new QueryParam(decodeComponent(piece.substring(0, eq)), decodeComponent(piece.substring(eq + 1))));
    }
  }
  return result;
}

const SCHEME_WITH_AUTHORITY: RegExp = new RegExp('^([a-zA-Z][a-zA-Z0-9+.\\-]*)://');
const SCHEME_ONLY: RegExp = new RegExp('^([a-zA-Z][a-zA-Z0-9+.\\-]*):');

/**
 * 解析 URI。支持 `scheme://authority/path?query#fragment` 与无 authority 的
 * `scheme:opaque`（mailto:、tel: 等，交给系统打开时只做方案判断）。
 */
export function parseUri(raw: string): UriParts {
  const parts: UriParts = new UriParts();
  let rest: string = raw.trim();
  if (rest.length === 0) {
    return parts;
  }

  const withAuthority: RegExpMatchArray | null = rest.match(SCHEME_WITH_AUTHORITY);
  if (withAuthority !== null) {
    parts.scheme = withAuthority[1].toLowerCase();
    rest = rest.substring(withAuthority[0].length);
  } else {
    const withScheme: RegExpMatchArray | null = rest.match(SCHEME_ONLY);
    if (withScheme !== null) {
      parts.scheme = withScheme[1].toLowerCase();
      rest = rest.substring(withScheme[0].length);
      // 无 `//`：整段是 opaque 路径，authority 为空。
      const hashAt: number = rest.indexOf('#');
      if (hashAt >= 0) {
        parts.fragment = rest.substring(hashAt + 1);
        rest = rest.substring(0, hashAt);
      }
      const queryAt: number = rest.indexOf('?');
      if (queryAt >= 0) {
        parts.query = rest.substring(queryAt + 1);
        rest = rest.substring(0, queryAt);
      }
      parts.path = rest;
      return parts;
    }
  }

  const hashAt: number = rest.indexOf('#');
  if (hashAt >= 0) {
    parts.fragment = rest.substring(hashAt + 1);
    rest = rest.substring(0, hashAt);
  }
  const queryAt: number = rest.indexOf('?');
  if (queryAt >= 0) {
    parts.query = rest.substring(queryAt + 1);
    rest = rest.substring(0, queryAt);
  }
  let pathAt: number = rest.indexOf('/');
  if (pathAt < 0) {
    pathAt = rest.length;
  }
  parts.authority = rest.substring(0, pathAt);
  parts.path = rest.substring(pathAt);
  return parts;
}

/** 组装 `scheme://authority/path?a=b`；参数值会做百分号编码，path 原样拼入。 */
export function buildUri(scheme: string, authority: string, path: string, params: QueryParam[]): string {
  let result: string = '';
  if (scheme.length > 0) {
    result += `${scheme}://`;
  }
  result += authority;
  result += path;
  if (params.length > 0) {
    const pieces: string[] = [];
    for (const param of params) {
      pieces.push(`${encodeComponent(param.name)}=${encodeComponent(param.value)}`);
    }
    result += `?${pieces.join('&')}`;
  }
  return result;
}

/** 服务器地址清洗：去首尾空白、去结尾 `/`（对齐上游 _getUrl()）。 */
export function normalizeServerUrl(raw: string): string {
  let value: string = raw.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

/** 合法服务器地址：http(s) 且带 authority（对齐上游 ErrorScreen 的 "Invalid URL" 判定）。 */
export function isValidServerUrl(raw: string): boolean {
  const value: string = normalizeServerUrl(raw);
  if (value.length === 0) {
    return false;
  }
  const parts: UriParts = parseUri(value);
  if (parts.scheme !== 'http' && parts.scheme !== 'https') {
    return false;
  }
  if (parts.authority.length === 0 || parts.host().length === 0) {
    return false;
  }
  return parts.host().indexOf(' ') < 0;
}

export function originOf(raw: string): string {
  return parseUri(raw).origin();
}

export function pathOf(raw: string): string {
  return parseUri(raw).path;
}

/** 路径最后一段（含扩展名），空路径返回空串。 */
export function lastPathSegment(raw: string): string {
  const segments: string[] = parseUri(raw).pathSegments();
  return segments.length === 0 ? '' : segments[segments.length - 1];
}

/** 是否属于需要原生下载并分享的附件（上游 _isDownloadable）。 */
export function isDownloadable(url: string, extensions: string[]): boolean {
  const segment: string = lastPathSegment(url);
  if (segment.length === 0) {
    return false;
  }
  const dot: number = segment.lastIndexOf('.');
  if (dot < 0 || dot === segment.length - 1) {
    return false;
  }
  const ext: string = segment.substring(dot + 1).toLowerCase();
  for (const candidate of extensions) {
    if (candidate === ext) {
      return true;
    }
  }
  return false;
}

/**
 * 把 OAuth 的 redirect_uri 改写成应用自定义 scheme（上游 _launchAuthorizeRequest）。
 *
 * `https://host/a/b?x=1` → `org.traccar.manager://a/b?x=1`
 * 即：第一段路径变成 host，其余保留为 path，query 原样搬运。这样外部浏览器完成登录后
 * 会被重定向回本应用。
 */
export function rewriteRedirectToAppScheme(redirectUri: string, appScheme: string): string {
  const parts: UriParts = parseUri(redirectUri);
  const segments: string[] = parts.pathSegments();
  if (segments.length === 0) {
    return redirectUri;
  }
  const host: string = segments[0];
  const tail: string[] = segments.slice(1);
  const path: string = tail.length === 0 ? '' : `/${tail.join('/')}`;
  return buildUri(appScheme, host, path, parts.queryParams());
}

/**
 * 把应用深链还原成服务器地址（上游 uriLinkStream 分支）。
 *
 * 服务器 `https://demo.traccar.org` + 深链 `org.traccar.manager://callback/auth?code=x`
 * → `https://demo.traccar.org/callback/auth?code=x`，并在带 `code` 时补一个
 * `redirect_uri`（值为不带 query 的深链本身）供 Web 端校验。
 */
export function composeServerUrlFromDeepLink(serverUrl: string, deepLink: string): string {
  const base: UriParts = parseUri(normalizeServerUrl(serverUrl));
  const link: UriParts = parseUri(deepLink);
  const segments: string[] = [];
  if (link.host().length > 0) {
    segments.push(link.host());
  }
  for (const segment of link.pathSegments()) {
    segments.push(segment);
  }
  const params: QueryParam[] = link.queryParams();
  let hasCode: boolean = false;
  for (const param of params) {
    if (param.name === 'code') {
      hasCode = true;
      break;
    }
  }
  if (hasCode) {
    const redirectPath: string = segments.length === 0 ? '' : `/${segments.join('/')}`;
    params.push(new QueryParam('redirect_uri', buildUri(link.scheme, link.host(), redirectPath, [])));
  }
  const path: string = segments.length === 0 ? '/' : `/${segments.map<string>((item: string) => item).join('/')}`;
  return buildUri(base.scheme, base.authority, path, params);
}

/** 是否为需要交给外部浏览器完成的 OAuth 授权请求。 */
export function isOAuthAuthorizeRequest(url: string, requiredParams: string[]): boolean {
  return parseUri(url).hasParams(requiredParams);
}

/** 当前 URL 是否已经处在服务器首页或登录页（决定返回键是回退还是退出）。 */
export function isServerRootOrLogin(url: string, serverUrl: string): boolean {
  const current: UriParts = parseUri(url);
  const server: UriParts = parseUri(normalizeServerUrl(serverUrl));
  if (current.origin().toLowerCase() !== server.origin().toLowerCase()) {
    return false;
  }
  const path: string = current.path.length === 0 ? '/' : current.path;
  const normalized: string = path.endsWith('/') && path.length > 1 ? path.substring(0, path.length - 1) : path;
  return normalized === '/' || normalized === '/login';
}
