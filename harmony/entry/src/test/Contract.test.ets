import { describe, it, expect } from '@ohos/hypium';
import { TraccarConstants } from '../main/ets/common/constants/TraccarConstants';

/**
 * 与 Traccar Web 端 / 旧版 Flutter 应用之间的契约常量。
 * 这些值一旦漂移，Web 端就发不出消息、或者升级用户会丢服务器地址与令牌，所以逐个钉住。
 */
export default function contractTest() {
  describe('contractTest', () => {

    it('keepsUpstreamStorageContract', 0, () => {
      expect(TraccarConstants.PREF_KEY_SERVER_URL).assertEqual('url');
      expect(TraccarConstants.SECRET_KEY_TOKEN).assertEqual('token');
      expect(TraccarConstants.DEFAULT_SERVER_URL).assertEqual('https://demo.traccar.org');
      expect(TraccarConstants.DEEP_LINK_SCHEME).assertEqual('org.traccar.manager');
    });

    it('keepsWebMessagePrefixes', 0, () => {
      expect(TraccarConstants.MESSAGE_LOGIN).assertEqual('login');
      expect(TraccarConstants.MESSAGE_AUTHENTICATION).assertEqual('authentication');
      expect(TraccarConstants.MESSAGE_AUTHENTICATED).assertEqual('authenticated');
      expect(TraccarConstants.MESSAGE_LOGOUT).assertEqual('logout');
      expect(TraccarConstants.MESSAGE_DOWNLOAD).assertEqual('download');
      expect(TraccarConstants.MESSAGE_SERVER).assertEqual('server');
    });

    it('keepsNativeCallbackNames', 0, () => {
      expect(TraccarConstants.JS_FN_UPDATE_NOTIFICATION_TOKEN).assertEqual('updateNotificationToken');
      expect(TraccarConstants.JS_FN_HANDLE_LOGIN_TOKEN).assertEqual('handleLoginToken');
      expect(TraccarConstants.JS_FN_HANDLE_NATIVE_NOTIFICATION).assertEqual('handleNativeNotification');
    });

    it('keepsProxyNamingApart', 0, () => {
      // 原生对象名与网页入口名必须不同，否则注入脚本会覆盖原生对象（见 TraccarConstants 注释）。
      expect(TraccarConstants.JS_PROXY_NAME).assertEqual('__traccarNativeInterface');
      expect(TraccarConstants.JS_BRIDGE_NAME).assertEqual('appInterface');
      expect(TraccarConstants.JS_PROXY_NAME !== TraccarConstants.JS_BRIDGE_NAME).assertTrue();
    });

    it('keepsDownloadAndOAuthRules', 0, () => {
      expect(TraccarConstants.DOWNLOADABLE_EXTENSIONS.join(',')).assertEqual('xlsx,kml,csv,gpx');
      expect(TraccarConstants.OAUTH_PARAMS.join(',')).assertEqual('response_type,client_id,redirect_uri,scope');
      expect(TraccarConstants.AUTHENTICATED_TIMEOUT_MS).assertEqual(30000);
    });
  });
}
